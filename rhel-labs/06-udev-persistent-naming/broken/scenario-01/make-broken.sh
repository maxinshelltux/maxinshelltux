#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=06-udev-persistent-naming/lib.sh
source "$MODULE_DIR/lib.sh"

MODE=dry-run
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "usage: $0 [--apply]"; exit 2 ;;
esac

need_root
need_bin lsblk

SPARE="$(spare_disk)"
[[ -n "$SPARE" ]] || fail "не нашёл пустой запасной диск — инцидент воспроизводить не на чем"
LINE="$SPARE  /mnt/labdata  xfs  defaults  0 0"

echo "Инцидент: в /etc/fstab добавили монтирование запасного диска ПО ИМЕНИ ЯДРА,"
echo "без nofail и без файловой системы на диске."
echo
echo "ВНИМАНИЕ: после перезагрузки монтирование упадёт, и система уйдёт в emergency —"
echo "без сети и SSH, а root на стенде заблокирован. Вернуть можно только с консоли"
echo "(лаба 04, rd.break). Запускайте с ментором и при открытой консоли."
echo

if [[ "$MODE" == dry-run ]]; then
  echo "[DRY-RUN] в $FSTAB была бы добавлена строка:"
  echo "    $LINE"
  echo "применить: sudo $0 --apply"
  exit 0
fi

install -d -m 700 "$LAB_STATE_DIR"
[[ -f "$LAB_STATE_DIR/fstab.before-scenario-01" ]] \
  || cp -a "$FSTAB" "$LAB_STATE_DIR/fstab.before-scenario-01"
printf '%s\n' "$LINE" >> "$FSTAB"
echo "добавлено в $FSTAB:"
grep -F "$SPARE" "$FSTAB"
echo
echo "Проверить запись, НЕ перезагружаясь: findmnt --verify"
echo "Перезагрузка воспроизведёт симптом (emergency)."
echo "разбор: broken/scenario-01/README.md · фикс: solutions/01-fstab-persistent/fix.sh"
