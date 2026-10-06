#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"
MEMHOG="$MODULE_DIR/memhog.py"

need_root
need_bin systemd-run
if unit_active || pgrep -f memhog.py >/dev/null; then
  fail "учебный процесс уже запущен: сначала sudo ./verify/cleanup.sh"
fi
[[ "$(meminfo_mib MemAvailable)" -ge 700 ]] || fail "доступно всего $(meminfo_mib MemAvailable) МиБ памяти — сценарию нужно не меньше 700"

start_hog 300 -p Restart=always -p RestartSec=2
PID="$(unit_pid)"
wait_rss_mib "$PID" 290 || fail "процесс $PID не набрал 290 МиБ"

echo "Заявка: «Память на сервере уходит. Нашёл процесс, который её ест, убил его —"
echo "через пару секунд он снова на месте и снова занимает столько же»."
echo
echo "Что видит автор заявки:"
echo "# free -m"
free -m
echo "# ps -eo pid,user,rss,pmem,args --sort=-rss | head -n 3"
ps -eo pid,user,rss,pmem,args --sort=-rss | head -n 3
echo
echo "разбор: broken/scenario-01/README.md · фикс: solutions/01-respawning-hog/fix.sh"
