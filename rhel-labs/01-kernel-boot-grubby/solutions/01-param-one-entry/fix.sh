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

echo "до исправления: записей с параметром $(entries_with_arg transparent_hugepage=never) из $(kernel_count)"
grubby --update-kernel=ALL --args="transparent_hugepage=never"
assert_eq "$(kernel_count)" "$(entries_with_arg transparent_hugepage=never)" "параметр во всех записях"
grubby --info=ALL | grep -E '^(index|kernel|args)='
ok "transparent_hugepage=never во всех записях, включая запись по умолчанию $(default_kernel)"
echo "осталось перезагрузиться и проверить: cat /proc/cmdline; cat /sys/kernel/mm/transparent_hugepage/enabled"
