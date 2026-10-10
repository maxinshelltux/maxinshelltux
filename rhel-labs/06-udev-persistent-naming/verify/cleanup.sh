#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=06-udev-persistent-naming/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin udevadm

RULES="$(lab_rules)"
if [[ -n "$RULES" ]]; then
  while IFS= read -r rule; do
    rm -f "$rule"
    echo "удалено правило: $rule"
  done <<< "$RULES"
  reload_udev
  udevadm trigger --subsystem-match=block --action=change
  udevadm settle
  LEFT="$(lab_rules)"
  [[ -z "$LEFT" ]] || fail "учебные правила остались: $LEFT"
  ok "учебные правила udev убраны, правила перечитаны"
else
  ok "учебных правил udev нет"
fi

SYMS="$(lab_symlinks)"
if [[ -n "$SYMS" ]]; then
  warn "остались симлинки /dev/lab-*: $SYMS — исчезнут после udevadm trigger или перезагрузки"
fi

KERNEL_ENTRIES="$(fstab_kernel_name_entries)"
if [[ -n "$KERNEL_ENTRIES" ]]; then
  warn "в /etc/fstab монтирование по имени ядра: $KERNEL_ENTRIES — fstab не трогаю, поправьте вручную (solutions/01-fstab-persistent)"
fi

ok "cleanup 06-udev-persistent-naming"
