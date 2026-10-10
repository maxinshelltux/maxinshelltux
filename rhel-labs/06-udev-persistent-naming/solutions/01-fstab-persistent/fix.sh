#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=06-udev-persistent-naming/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin findmnt

BAD="$(fstab_kernel_name_entries)"
if [[ -z "$BAD" ]]; then
  ok "в /etc/fstab нет монтирования по имени ядра — чинить нечего"
  exit 0
fi
echo "в /etc/fstab монтирование по имени ядра: $BAD"

BACKUP="$LAB_STATE_DIR/fstab.before-scenario-01"
if [[ -f "$BACKUP" ]]; then
  cp -a "$FSTAB" "$LAB_STATE_DIR/fstab.broken-$(date -u +%Y%m%d-%H%M%S)"
  cp -a "$BACKUP" "$FSTAB"
  echo "восстановлен /etc/fstab из снимка $BACKUP"
else
  fail "снимка $BACKUP нет: уберите сбойную строку из /etc/fstab вручную (или перепишите по UUID с nofail)"
fi

LEFT="$(fstab_kernel_name_entries)"
[[ -z "$LEFT" ]] || fail "монтирование по имени ядра всё ещё в fstab: $LEFT"
ok "в /etc/fstab не осталось монтирования по имени ядра"
echo "проверка записи без перезагрузки:"
findmnt --verify
