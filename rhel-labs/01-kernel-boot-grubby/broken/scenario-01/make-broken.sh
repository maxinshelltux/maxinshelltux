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

DEFAULT="$(default_kernel)"
OTHER=""
while IFS= read -r kernel; do
  if [[ "$kernel" != "$DEFAULT" ]]; then
    OTHER="$kernel"
  fi
done < <(kernels)
[[ -n "$OTHER" ]] || fail "не нашёл запись, отличную от записи по умолчанию"

grubby --update-kernel=ALL --remove-args="transparent_hugepage"
grubby --update-kernel="$OTHER" --args="transparent_hugepage=never"

echo "Заявка: «Добавил transparent_hugepage=never через grubby, перезагрузил сервер —"
echo "а THP всё ещё включён. grubby показывает, что параметр на месте»."
echo
echo "Что видит автор заявки:"
echo "# grubby --info=ALL | grep -c transparent_hugepage=never"
grubby --info=ALL | grep -c 'transparent_hugepage=never' || true
echo
echo "Перезагрузись (systemctl reboot) и воспроизведи симптом:"
echo "  cat /proc/cmdline"
echo "  cat /sys/kernel/mm/transparent_hugepage/enabled"
echo
echo "разбор: broken/scenario-01/README.md · фикс: solutions/01-param-one-entry/fix.sh"
