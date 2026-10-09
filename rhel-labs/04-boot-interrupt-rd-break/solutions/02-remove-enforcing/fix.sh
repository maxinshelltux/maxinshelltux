#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby

BEFORE="$(places_with_arg enforcing)"
if [[ -z "$BEFORE" ]]; then
  ok "enforcing в записях и шаблонах нет — чинить нечего"
  exit 0
fi
echo "до: enforcing найден в: $BEFORE"
grubby --update-kernel=ALL --remove-args="enforcing"
AFTER="$(places_with_arg enforcing)"
echo "после: ${AFTER:-enforcing нигде не найден}"
[[ -z "$AFTER" ]] || fail "enforcing всё ещё в: $AFTER"
ok "enforcing=0 убран из всех записей и шаблона"
echo "осталось перезагрузиться и проверить: getenforce"
