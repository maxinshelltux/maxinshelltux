#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=05-systemd-targets/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby

BEFORE="$(places_with_arg systemd.unit)"
if [[ -z "$BEFORE" ]]; then
  ok "systemd.unit= в записях нет — чинить нечего"
  exit 0
fi
echo "до: systemd.unit= найден в: $BEFORE"
remove_lab_keys
AFTER="$(places_with_arg systemd.unit)"
echo "после: ${AFTER:-systemd.unit= нигде не найден}"
[[ -z "$AFTER" ]] || fail "systemd.unit= всё ещё в: $AFTER"
ok "systemd.unit= убран из всех записей"
echo "осталось перезагрузиться и проверить: grep systemd.unit /proc/cmdline"
