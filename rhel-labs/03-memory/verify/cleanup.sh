#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"

MODE=dry-run
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "usage: $0 [--apply]"; exit 2 ;;
esac

need_root
need_bin swapoff
need_bin lsblk

stop_lab_units
if pgrep -f memhog.py >/dev/null; then
  warn "остались процессы memhog.py, запущенные не через $LAB_UNIT: $(pgrep -f memhog.py | tr '\n' ' ')"
else
  ok "учебные процессы остановлены, $LAB_UNIT неактивен"
fi

DEV="$(lab_swap_dev)"
if [[ -z "$DEV" ]]; then
  ok "раздела $LAB_SWAP_LABEL нет, строки в /etc/fstab нет"
  ok "cleanup 03-memory ($MODE)"
  exit 0
fi

UUID="$(lab_swap_uuid)"
if lab_swap_active; then
  swapoff "$DEV"
  ok "swap на $DEV отключён"
fi

LINE="$(fstab_swap_line)"
if [[ -n "$LINE" ]]; then
  [[ "$(echo "$LINE" | wc -l)" -eq 1 ]] || fail "в /etc/fstab несколько строк с UUID=$UUID — разберись вручную"
  sed -i -E "/^UUID=${UUID}[[:space:]]+none[[:space:]]+swap[[:space:]]/d" /etc/fstab
  systemctl daemon-reload
  ok "строка swap UUID=$UUID убрана из /etc/fstab"
fi

DISK="/dev/$(lsblk -no PKNAME "$DEV")"
NUMBER="$(cat "/sys/class/block/$(basename "$DEV")/partition")"
SIZE="$(lsblk -dno SIZE "$DEV")"
if [[ "$MODE" == dry-run ]]; then
  echo "[DRY-RUN] был бы удалён раздел: $DEV (номер $NUMBER на $DISK, $SIZE, PARTLABEL=$LAB_SWAP_LABEL, TYPE=$(lsblk -dno FSTYPE "$DEV"))"
  warn "раздел $LAB_SWAP_LABEL остаётся; удаляет его только запуск с ключом: sudo ./verify/cleanup.sh --apply"
else
  [[ "$(lsblk -dno PARTLABEL "$DEV")" == "$LAB_SWAP_LABEL" ]] || fail "у $DEV метка раздела не $LAB_SWAP_LABEL — не трогаю"
  [[ "$(lsblk -dno FSTYPE "$DEV")" == swap ]] || fail "на $DEV не swap, а «$(lsblk -dno FSTYPE "$DEV")» — не трогаю"
  if findmnt -n -S "$DEV" >/dev/null || lab_swap_active; then
    fail "$DEV используется — не трогаю"
  fi
  if lsblk -no MOUNTPOINTS "$DISK" | grep -qxE '/|/boot|/boot/efi'; then
    fail "$DISK — системный диск, раздел на нём не трогаю"
  fi
  wipefs -a "$DEV"
  parted -s "$DISK" rm "$NUMBER"
  udevadm settle
  echo "[APPLY] удалён раздел $DEV (номер $NUMBER на $DISK, $SIZE)"
fi

ok "cleanup 03-memory ($MODE)"
