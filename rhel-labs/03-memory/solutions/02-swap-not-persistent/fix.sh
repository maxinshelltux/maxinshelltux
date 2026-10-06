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
[[ -n "$DEV" ]] || fail "нет раздела $LAB_SWAP_LABEL"
UUID="$(lab_swap_uuid)"
[[ -n "$UUID" ]] || fail "у $DEV нет UUID: на разделе нет сигнатуры swap (mkswap $DEV)"

echo "до исправления: swap на $DEV подключён: $(lab_swap_active && echo да || echo нет), строка в /etc/fstab: $(fstab_swap_line | grep . || echo нет)"
if [[ -z "$(fstab_swap_line)" ]]; then
  printf 'UUID=%s none swap defaults 0 0\n' "$UUID" >> /etc/fstab
fi
systemctl daemon-reload
swapon -a
lab_swap_active || fail "swapon -a не подключил $DEV — проверь строку в /etc/fstab"
grep -n swap /etc/fstab
swapon --show
ok "swap прописан в /etc/fstab по UUID и подключён"
echo "осталось перезагрузиться и проверить: swapon --show; free -m"
