#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin swapon

DEV="$(lab_swap_dev)"
[[ -n "$DEV" ]] || fail "нет раздела $LAB_SWAP_LABEL: сначала выполните часть 6 README или задание tasks/02"
[[ "$(lsblk -dno FSTYPE "$DEV")" == swap ]] || fail "на $DEV нет сигнатуры swap: mkswap $DEV"
UUID="$(lab_swap_uuid)"

if [[ -n "$(fstab_swap_line)" ]]; then
  sed -i -E "/^UUID=${UUID}[[:space:]]+none[[:space:]]+swap[[:space:]]/d" /etc/fstab
  systemctl daemon-reload
fi
if ! lab_swap_active; then
  swapon "$DEV"
fi

echo "Заявка: «Добавил серверу swap, проверил — работает. После перезагрузки"
echo "swap пропал, хотя раздел на месте»."
echo
echo "Что видит автор заявки до перезагрузки:"
echo "# swapon --show"
swapon --show
echo "# free -m | tail -n 1"
free -m | tail -n 1
echo
echo "Перезагрузись (systemctl reboot) и воспроизведи симптом:"
echo "  swapon --show"
echo "  free -m"
echo
echo "разбор: broken/scenario-02/README.md · фикс: solutions/02-swap-not-persistent/fix.sh"
