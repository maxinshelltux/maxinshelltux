#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=01-kernel-boot-grubby/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby

NEWEST="$(newest_kernel)"
echo "до исправления: по умолчанию $(default_kernel) (index $(default_index))"
grubby --set-default "$NEWEST"
assert_eq "$NEWEST" "$(default_kernel)" "ядро по умолчанию"
ok "по умолчанию самое новое ядро: $NEWEST (index $(default_index))"
echo "осталось перезагрузиться и проверить: uname -r"
