#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin free
need_bin lsblk

echo "=== Память системы, МиБ ==="
free -m
echo

echo "=== Что стоит за этими числами (/proc/meminfo, МиБ) ==="
for key in MemTotal MemFree MemAvailable Cached AnonPages SwapTotal SwapFree CommitLimit Committed_AS; do
  printf '%-14s %6s\n' "$key" "$(meminfo_mib "$key")"
done
echo "vm.overcommit_memory = $(cat /proc/sys/vm/overcommit_memory), vm.overcommit_ratio = $(cat /proc/sys/vm/overcommit_ratio), vm.swappiness = $(cat /proc/sys/vm/swappiness)"
echo

echo "=== Пять процессов с наибольшим RSS ==="
ps -eo pid,user,rss,vsz,pmem,comm --sort=-rss | head -n 6
echo

echo "=== Учебный процесс ==="
if unit_active; then
  PID="$(unit_pid)"
  echo "$LAB_UNIT активен, PID $PID, VmRSS $(( $(status_kb "$PID" VmRSS) / 1024 )) МиБ, Restart=$(systemctl show -p Restart --value "$LAB_UNIT")"
else
  echo "$LAB_UNIT не запущен"
fi
STRAY="$(pgrep -f memhog.py | tr '\n' ' ' || true)"
echo "процессы memhog.py: ${STRAY:-нет}"
echo

echo "=== Swap ==="
if [[ -n "$(swapon --noheadings --show)" ]]; then
  swapon --show
else
  echo "активных областей swap нет"
fi
DEV="$(lab_swap_dev)"
if [[ -n "$DEV" ]]; then
  echo "раздел $LAB_SWAP_LABEL: $DEV, $(lsblk -dno SIZE "$DEV"), TYPE=$(lsblk -dno FSTYPE "$DEV"), UUID=$(lab_swap_uuid)"
else
  echo "раздел $LAB_SWAP_LABEL: не создан; пустые диски: $(empty_disks | tr '\n' ' ')"
fi
echo

echo "=== Что будет после перезагрузки ==="
FAILED="$(systemctl --failed --no-legend --plain | awk '{print $1}' | grep -E '^(lab-|run-p)' | tr '\n' ' ' || true)"
if [[ -n "${FAILED// /}" ]]; then
  warn "есть упавшие учебные юниты (${FAILED% }) — система в состоянии degraded: systemctl reset-failed <юнит>"
fi
if [[ -z "$DEV" ]]; then
  ok "swap не настроен — после перезагрузки его не будет"
elif [[ -n "$(fstab_swap_line)" ]]; then
  ok "swap $DEV прописан в /etc/fstab по UUID — после перезагрузки подключится сам"
elif lab_swap_active; then
  warn "swap $DEV подключён сейчас, но строки в /etc/fstab нет — после перезагрузки пропадёт"
else
  ok "раздел $DEV есть, но swap не подключён и в /etc/fstab не прописан"
fi
