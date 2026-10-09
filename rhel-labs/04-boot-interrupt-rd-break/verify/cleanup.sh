#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby
need_bin grub2-editenv
need_bin getenforce
need_bin restorecon

PERSISTENT="$(lab_keys_in_config)"
if [[ -n "$PERSISTENT" ]]; then
  remove_lab_keys
  LEFT="$(lab_keys_in_config)"
  [[ -z "$LEFT" ]] || fail "параметры лабы остались в постоянной конфигурации: $LEFT"
  ok "из записей загрузчика и шаблонов убраны параметры лабы: $PERSISTENT"
else
  ok "в записях загрузчика и шаблонах нет параметров лабы"
fi

RUNNING_KEYS="$(lab_keys_in_running)"
if [[ -n "$RUNNING_KEYS" ]]; then
  warn "система сейчас загружена с параметром из лабы ($RUNNING_KEYS) — перезагрузись: systemctl reboot"
fi

if [[ "$(getenforce)" != "Enforcing" ]]; then
  warn "SELinux сейчас в режиме $(getenforce): вернуть без перезагрузки — setenforce 1"
fi

LABEL_PROBLEM="$(shadow_label_problem)"
if [[ -n "$LABEL_PROBLEM" ]]; then
  warn "метка /etc/shadow не та, что требует политика ($(shadow_context)): исправить — restorecon -v /etc/shadow"
fi

if [[ -e /.autorelabel ]]; then
  warn "есть /.autorelabel: при следующей загрузке система перемаркирует файлы и перезагрузится ещё раз — файл не трогаю"
fi

case "$(root_password_status)" in
  P) warn "пароль root задан и оставлен как есть; заблокировать снова решает ментор: passwd -l root" ;;
  L) ok "учётная запись root заблокирована, как в исходном образе" ;;
  *) warn "неожиданное состояние пароля root: $(passwd -S root)" ;;
esac

ok "cleanup 04-boot-interrupt-rd-break"
