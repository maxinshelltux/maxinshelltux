#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=01-kernel-boot-grubby/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby
need_bin grub2-editenv

remove_lab_params
grub2-editenv - unset next_entry
NEWEST="$(newest_kernel)"
grubby --set-default "$NEWEST" >/dev/null 2>&1

LEFT="$(lab_params_in_config)"
[[ -z "$LEFT" ]] || fail "параметры лабы остались в записях: $LEFT"
assert_eq "$NEWEST" "$(default_kernel)" "ядро по умолчанию после уборки"
ok "записи загрузчика без параметров лабы, по умолчанию $NEWEST"

RUNNING_PARAMS="$(lab_params_in_running)"
if [[ -n "$RUNNING_PARAMS" || "/boot/vmlinuz-$(uname -r)" != "$NEWEST" ]]; then
  warn "работающая система ещё в старом состоянии (ядро $(uname -r), параметры: ${RUNNING_PARAMS:-нет}) — перезагрузись: systemctl reboot"
fi

ok "cleanup 01-kernel-boot-grubby"
