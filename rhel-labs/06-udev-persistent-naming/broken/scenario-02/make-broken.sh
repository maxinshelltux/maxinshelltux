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

SPARE="$(spare_disk)"
[[ -n "$SPARE" ]] || fail "не нашёл пустой запасной диск — не на чем ставить правило"
SHORT="$(serial_short "$SPARE")"
[[ -n "$SHORT" ]] || fail "у $SPARE нет ID_SERIAL_SHORT"

RULE="$RULE_DIR/${LAB_RULE_PREFIX}broken.rules"

echo "Инцидент: правило udev написано с НЕ тем ключом — симлинк /dev/lab-spare не появится."
echo "Доступ по SSH при этом не теряется: правило лишь не срабатывает."
echo
echo "пишем $RULE с ключом ID_SERIAL (длинная форма) против короткого значения:"
printf '%s\n' "SUBSYSTEM==\"block\", ENV{ID_SERIAL}==\"$SHORT\", SYMLINK+=\"lab-spare\"" | tee "$RULE"
udevadm control --reload
udevadm trigger --name-match="$(basename "$SPARE")" --action=change
udevadm settle
echo
echo "симлинк /dev/lab-spare:"
ls -l /dev/lab-spare 2>&1
echo
echo "разбор: broken/scenario-02/README.md · фикс: solutions/02-fix-udev-rule/fix.sh"
