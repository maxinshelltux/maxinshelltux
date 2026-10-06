#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin ps

PID="$(top_rss_pid)"
echo "самый прожорливый процесс:"
ps -o pid,ppid,user,rss,pmem,args -p "$PID"
UNIT="$(ps -o unit= -p "$PID" | tr -d ' ')"
echo "его юнит: $UNIT, Restart=$(systemctl show -p Restart --value "$UNIT")"
[[ "$UNIT" == "$LAB_UNIT" ]] || fail "этот процесс не из $LAB_UNIT, а из $UNIT — останавливать его не буду"
systemctl stop "$UNIT"
wait_gone "$PID" || fail "процесс $PID не остановился"
sleep 3
if pgrep -f memhog.py >/dev/null; then
  fail "memhog.py снова запущен: $(pgrep -af memhog.py)"
fi
ok "$UNIT остановлен, процесс не вернулся"
free -m
