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
[[ "$(kernel_count)" -ge 2 ]] || fail "нужно минимум два ядра (запусти verify/prepare.sh)"

OLDEST="$(oldest_kernel)"
INDEX="$(index_of_kernel "$OLDEST")"

echo "Заявка: «Поставили обновление ядра и перезагрузились, а uname -r показывает"
echo "старую версию. Перед перезагрузкой я ещё явно выбрал запись по индексу —"
echo "самую новую, как мне казалось»."
echo
echo "Что сделал автор заявки:"
echo "# grubby --set-default-index=$INDEX"
grubby --set-default-index="$INDEX" 2>&1
echo
echo "Перезагрузись (systemctl reboot) и воспроизведи симптом:"
echo "  uname -r"
echo "  rpm -q kernel"
echo
echo "разбор: broken/scenario-02/README.md · фикс: solutions/02-default-pinned/fix.sh"
