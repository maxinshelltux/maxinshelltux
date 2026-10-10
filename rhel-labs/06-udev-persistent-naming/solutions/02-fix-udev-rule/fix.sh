#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=06-udev-persistent-naming/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin udevadm

RULES="$(lab_rules)"
if [[ -z "$RULES" ]]; then
  ok "учебных правил udev нет — чинить нечего"
else
  while IFS= read -r rule; do
    rm -f "$rule"
    echo "удалено сбойное правило: $rule"
  done <<< "$RULES"
  reload_udev
  udevadm trigger --subsystem-match=block --action=change
  udevadm settle
  LEFT="$(lab_rules)"
  [[ -z "$LEFT" ]] || fail "правила остались: $LEFT"
  ok "сбойные учебные правила убраны, правила перечитаны"
fi

SPARE="$(spare_disk)"
if [[ -n "$SPARE" ]]; then
  echo "верный ключ для запасного диска $SPARE:"
  echo "    ENV{ID_SERIAL_SHORT}==\"$(serial_short "$SPARE")\""
  echo "правильное правило см. tasks/03-udev-symlink.md"
fi
