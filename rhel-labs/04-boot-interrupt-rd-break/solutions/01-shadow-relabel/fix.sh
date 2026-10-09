#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin restorecon

echo "до: $(shadow_context) /etc/shadow"
PROBLEM="$(shadow_label_problem)"
if [[ -z "$PROBLEM" ]]; then
  ok "метка /etc/shadow уже соответствует политике — чинить нечего"
  exit 0
fi
echo "restorecon исправит: $PROBLEM"
restorecon -v /etc/shadow
echo "после: $(shadow_context) /etc/shadow"
[[ -z "$(shadow_label_problem)" ]] || fail "метка всё ещё не та"
ok "метка /etc/shadow соответствует политике"
if [[ "$(getenforce)" != "Enforcing" ]]; then
  warn "SELinux сейчас в режиме $(getenforce) — верните Enforcing: setenforce 1"
fi
