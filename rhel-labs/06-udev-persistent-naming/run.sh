#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=06-udev-persistent-naming/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin udevadm
need_bin blkid
need_bin lsblk
need_bin findmnt

echo "=== Диски и постоянные имена ==="
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,SERIAL
echo
ROOT_DEV="$(root_source)"
echo "корень смонтирован с: $ROOT_DEV"
echo "его постоянные имена (DEVLINKS):"
devlinks "$ROOT_DEV" | tr ' ' '\n' | sed 's/^/     /'
echo

echo "=== Каталоги /dev/disk ==="
MISSING="$(missing_persist_dirs)"
if [[ -z "$MISSING" ]]; then
  for d in $PERSIST_DIRS; do
    printf '  %-22s %s ссылок\n' "$d" "$(find "$d" -maxdepth 1 -type l | wc -l)"
  done
  ok "каталоги постоянных имён на месте"
else
  warn "нет каталогов постоянных имён: $MISSING"
fi
echo

echo "=== fstab: по чему монтируется ==="
findmnt --fstab --noheadings | sed 's/^/  /'
KERNEL_ENTRIES="$(fstab_kernel_name_entries)"
UNRESOLVED="$(fstab_unresolved)"
if [[ -n "$KERNEL_ENTRIES" ]]; then
  warn "в fstab есть монтирование по имени ядра (неустойчиво): $KERNEL_ENTRIES"
fi
if [[ -n "$UNRESOLVED" ]]; then
  warn "в fstab есть UUID/LABEL, которых нет в системе: $UNRESOLVED"
fi
if [[ -z "$KERNEL_ENTRIES$UNRESOLVED" ]]; then
  ok "fstab монтирует по UUID/LABEL, все идентификаторы разрешаются"
fi
echo

echo "=== Запасной диск и правила udev ==="
SPARE="$(spare_disk)"
echo "запасной диск без ФС: ${SPARE:-нет}"
if [[ -n "$SPARE" ]]; then
  echo "его серийный номер (ID_SERIAL_SHORT): $(serial_short "$SPARE")"
fi
RULES="$(lab_rules)"
SYMS="$(lab_symlinks)"
if [[ -n "$RULES" ]]; then
  warn "есть учебные правила udev:"
  while IFS= read -r rule; do echo "     $rule"; done <<< "$RULES"
else
  ok "учебных правил udev ($RULE_DIR/${LAB_RULE_PREFIX}*.rules) нет"
fi
if [[ -n "$SYMS" ]]; then
  warn "есть учебные симлинки /dev/lab-*:"
  while IFS= read -r sym; do echo "     $sym"; done <<< "$SYMS"
fi
