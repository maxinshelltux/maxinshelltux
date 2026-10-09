#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin grubby
need_bin grub2-editenv
need_bin lsinitrd
need_bin getenforce
need_bin restorecon

SERIAL="$(serial_console)"
[[ -n "$SERIAL" ]] || fail "среди консолей ядра нет последовательного порта: $(kernel_consoles)"
ok "ядро пишет в последовательный порт: консоли $(kernel_consoles)"

assert_eq "active" "$(systemctl is-active "serial-getty@$SERIAL.service" || true)" "приглашение входа на $SERIAL"
ok "serial-getty@$SERIAL.service активна: в консоли есть приглашение входа"

MENU_PROBLEM="$(grub_menu_problem)"
[[ -z "$MENU_PROBLEM" ]] || fail "$MENU_PROBLEM"
ok "меню GRUB выводится в последовательный порт и ждёт $(grub_cfg_timeout) с"

DEFAULT="$(default_kernel)"
IMAGE="$(initramfs_image "$DEFAULT")"
require_file "$IMAGE" "initramfs ядра по умолчанию"
LISTING="$(initramfs_listing "$IMAGE")"
for path in $LAB_INITRAMFS_PATHS; do
  listing_has "$LISTING" "$path" || fail "в $IMAGE нет $path: оболочка rd.break не запустится"
done
ok "в initramfs ядра по умолчанию есть всё для оболочки rd.break: sulogin, dracut-emergency, chroot, mount"

assert_eq "empty" "$(initramfs_root_password "$IMAGE")" "пароль root внутри initramfs"
ok "внутри initramfs у root пустой пароль: оболочка rd.break не спрашивает пароль установленной системы"

PERSISTENT="$(lab_keys_in_config)"
[[ -z "$PERSISTENT" ]] \
  || fail "в постоянной конфигурации загрузчика остались параметры из лабы: $PERSISTENT (sudo ./verify/cleanup.sh)"
ok "в записях загрузчика и шаблонах нет параметров из лабы ($LAB_BOOT_KEYS)"

RUNNING_KEYS="$(lab_keys_in_running)"
[[ -z "$RUNNING_KEYS" ]] \
  || fail "система сейчас загружена с разовым параметром из лабы: $RUNNING_KEYS — перезагрузись без правки"
ok "текущая загрузка прошла без разовых параметров из лабы"

[[ ! -e /.autorelabel ]] \
  || fail "есть /.autorelabel: перемаркировка ещё не выполнена, перезагрузись и дождись второй перезагрузки"
ok "/.autorelabel нет: перемаркировка не ожидается"

assert_eq "Enforcing" "$(getenforce)" "режим SELinux"
assert_eq "enforcing" "$(sed -n 's/^SELINUX=//p' /etc/selinux/config)" "SELINUX в /etc/selinux/config"
ok "SELinux в режиме Enforcing, и в /etc/selinux/config тоже enforcing"

LABEL_PROBLEM="$(shadow_label_problem)"
[[ -z "$LABEL_PROBLEM" ]] || fail "метка /etc/shadow не та, что требует политика: $LABEL_PROBLEM"
ok "метка /etc/shadow соответствует политике: $(shadow_context)"

case "$(root_password_status)" in
  P) ok "пароль root задан: вход root в консоли возможен" ;;
  L) warn "учётная запись root заблокирована: войти под root в консоли нельзя, задание 03 ещё не выполнено" ;;
  *) fail "неожиданное состояние пароля root: $(passwd -S root)" ;;
esac

ok "module 04-boot-interrupt-rd-break verified"
