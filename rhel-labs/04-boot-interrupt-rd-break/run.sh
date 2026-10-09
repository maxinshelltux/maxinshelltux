#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby
need_bin grub2-editenv
need_bin lsinitrd
need_bin getenforce
need_bin restorecon

DEFAULT="$(default_kernel)"
IMAGE="$(initramfs_image "$DEFAULT")"

echo "=== Консоль ==="
echo "консоли ядра (последняя — /dev/console): $(kernel_consoles)"
SERIAL="$(serial_console)"
if [[ -n "$SERIAL" ]]; then
  echo "вход в консоли: serial-getty@$SERIAL.service — $(systemctl is-active "serial-getty@$SERIAL.service" || true)"
else
  echo "последовательной консоли среди консолей ядра нет"
fi
echo

echo "=== Меню GRUB ==="
echo "GRUB_TIMEOUT:        $(grub_default_value GRUB_TIMEOUT)"
echo "GRUB_TERMINAL:       $(grub_default_value GRUB_TERMINAL)"
echo "GRUB_SERIAL_COMMAND: $(grub_default_value GRUB_SERIAL_COMMAND)"
echo "timeout в grub.cfg:  $(grub_cfg_timeout)"
MENU_PROBLEM="$(grub_menu_problem)"
if [[ -z "$MENU_PROBLEM" ]]; then
  ok "меню GRUB показывается в последовательной консоли и ждёт $(grub_cfg_timeout) с"
else
  warn "$MENU_PROBLEM"
fi
echo

echo "=== Что загрузится и с какими параметрами ==="
echo "ядро по умолчанию: $DEFAULT"
echo "args записи:       $(entry_args "$DEFAULT")"
echo "/proc/cmdline:     $(cat /proc/cmdline)"
ONLY_RUNNING="$(words_only_running)"
ONLY_CONFIGURED="$(words_only_configured)"
if [[ -n "$ONLY_RUNNING" ]]; then
  warn "в /proc/cmdline есть слова, которых нет в записи работающего ядра: $ONLY_RUNNING — разовая правка в меню GRUB или запись изменили после загрузки"
fi
if [[ -n "$ONLY_CONFIGURED" ]]; then
  warn "в записи работающего ядра есть слова, которых нет в /proc/cmdline: $ONLY_CONFIGURED — вступят в силу после перезагрузки"
fi
if [[ -z "$ONLY_RUNNING$ONLY_CONFIGURED" ]]; then
  ok "система загружена с параметрами из записи, разовых правок нет"
fi
PERSISTENT="$(lab_keys_in_config)"
if [[ -n "$PERSISTENT" ]]; then
  warn "в постоянной конфигурации есть параметры из лабы: $PERSISTENT"
  for key in $PERSISTENT; do
    echo "     $key: $(places_with_arg "$key")"
  done
else
  ok "в записях загрузчика и шаблонах нет параметров из лабы ($LAB_BOOT_KEYS)"
fi
echo

echo "=== initramfs ядра по умолчанию ==="
echo "образ: $IMAGE"
LISTING="$(initramfs_listing "$IMAGE")"
for path in $LAB_INITRAMFS_PATHS; do
  if listing_has "$LISTING" "$path"; then
    echo "есть  $path"
  else
    echo "НЕТ   $path"
  fi
done
echo "пароль root внутри initramfs: $(initramfs_root_password "$IMAGE")"
echo

echo "=== SELinux и учётная запись root ==="
echo "режим:               $(getenforce)"
echo "метка /etc/shadow:   $(shadow_context)"
LABEL_PROBLEM="$(shadow_label_problem)"
if [[ -n "$LABEL_PROBLEM" ]]; then
  warn "метка /etc/shadow не та, что требует политика: $LABEL_PROBLEM"
fi
if [[ -e /.autorelabel ]]; then
  warn "есть /.autorelabel: при следующей загрузке система перемаркирует файлы и перезагрузится ещё раз"
else
  echo "/.autorelabel:       нет"
fi
echo "пароль root:         $(root_password_words) ($(passwd -S root))"
