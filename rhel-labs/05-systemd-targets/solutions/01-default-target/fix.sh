#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=05-systemd-targets/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin systemctl

echo "до: target по умолчанию $(default_target)"
PROBLEM="$(default_target_problem)"
if [[ -z "$PROBLEM" ]]; then
  ok "target по умолчанию уже $BASELINE_TARGET — чинить нечего"
  exit 0
fi
echo "проблема: $PROBLEM"
systemctl set-default "$BASELINE_TARGET"
echo "после: target по умолчанию $(default_target)"
[[ -z "$(default_target_problem)" ]] || fail "target по умолчанию всё ещё не $BASELINE_TARGET"
ok "target по умолчанию возвращён на $BASELINE_TARGET"
echo "осталось перезагрузиться и проверить: systemctl get-default"
