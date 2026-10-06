#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"
MEMHOG="$MODULE_DIR/memhog.py"

need_root
need_rhel10
need_bin systemd-run
need_bin ps

if unit_active || pgrep -f memhog.py >/dev/null; then
  refuse "учебный процесс memhog уже запущен: сначала sudo ./verify/cleanup.sh"
fi
[[ "$(meminfo_mib MemAvailable)" -ge 700 ]] \
  || refuse "доступно всего $(meminfo_mib MemAvailable) МиБ памяти — проверке нужно не меньше 700"

finish() {
  stop_lab_units
}
trap finish EXIT

field() {
  sed -n "s/^$2 .*$3= *\([0-9]*\).*/\1/p" <<< "$1" | head -n 1
}

OUT="$("$PYTHON" "$MEMHOG" 200)"
START_RSS="$(field "$OUT" старт VmRSS)"
START_SIZE="$(field "$OUT" старт VmSize)"
MAP_RSS="$(field "$OUT" "после mmap" VmRSS)"
MAP_SIZE="$(field "$OUT" "после mmap" VmSize)"
[[ $((MAP_SIZE - START_SIZE)) -ge 200 ]] || fail "после mmap 200 МиБ VmSize вырос всего на $((MAP_SIZE - START_SIZE)) МиБ"
[[ $((MAP_RSS - START_RSS)) -lt 20 ]] || fail "после mmap без записи VmRSS вырос на $((MAP_RSS - START_RSS)) МиБ"
ok "запрос памяти: VmSize +$((MAP_SIZE - START_SIZE)) МиБ, VmRSS +$((MAP_RSS - START_RSS)) МиБ — страницы ещё не выданы"

OUT="$("$PYTHON" "$MEMHOG" 200 --touch)"
START_RSS="$(field "$OUT" старт VmRSS)"
TOUCH_RSS="$(field "$OUT" "после записи" VmRSS)"
[[ $((TOUCH_RSS - START_RSS)) -ge 190 ]] || fail "после записи в 200 МиБ VmRSS вырос всего на $((TOUCH_RSS - START_RSS)) МиБ"
ok "запись в страницы: VmRSS +$((TOUCH_RSS - START_RSS)) МиБ — память выдана при первом обращении"

if [[ "$(cat /proc/sys/vm/overcommit_memory)" == 0 ]]; then
  HUGE=$(( ($(meminfo_mib MemTotal) + $(meminfo_mib SwapTotal)) * 2 ))
  require_fails "запрос $HUGE МиБ при эвристическом overcommit" "$PYTHON" "$MEMHOG" "$HUGE"
  ok "overcommit: запрос $HUGE МиБ (вдвое больше RAM и swap) ядро отклоняет сразу"
else
  warn "vm.overcommit_memory не 0 — проверку эвристики пропускаю"
fi

start_hog 200
PID="$(unit_pid)"
[[ "$PID" -gt 1 ]] || fail "$LAB_UNIT не запустился: systemctl status $LAB_UNIT"
wait_rss_mib "$PID" 190 || fail "процесс $PID не набрал 190 МиБ за 10 секунд"
assert_eq "$PID" "$(top_rss_pid)" "первый в ps --sort=-rss — учебный процесс"
ok "поиск: ps --sort=-rss ставит учебный процесс (PID $PID, $(( $(status_kb "$PID" VmRSS) / 1024 )) МиБ) первым"

kill "$PID"
wait_gone "$PID" || fail "процесс $PID не завершился по SIGTERM"
if unit_active; then
  fail "$LAB_UNIT остался активным после kill"
fi
ok "kill: процесс завершён по SIGTERM, память возвращена"

start_hog 200 -p Restart=always -p RestartSec=1
FIRST="$(unit_pid)"
wait_rss_mib "$FIRST" 190 || fail "процесс $FIRST не набрал 190 МиБ"
kill "$FIRST"
SECOND="$FIRST"
for _ in $(seq 1 40); do
  SECOND="$(unit_pid)"
  if [[ "$SECOND" -gt 1 && "$SECOND" != "$FIRST" ]]; then
    break
  fi
  sleep 0.25
done
assert_ne "$FIRST" "$SECOND" "после kill systemd запустил процесс заново с новым PID"
systemctl stop "$LAB_UNIT"
wait_gone "$SECOND" || fail "процесс $SECOND не остановился после systemctl stop"
ok "Restart=always: после kill процесс возвращается (PID $FIRST -> $SECOND), останавливает его только systemctl stop"

SINCE="$(date '+%F %T')"
set +e
bash -c '"$@"; exit $?' _ systemd-run --quiet --scope --unit="${LAB_OOM_UNIT%.scope}" \
  -p MemoryMax=100M -p MemorySwapMax=0 "$PYTHON" "$MEMHOG" 300 --touch >/dev/null 2>&1
RC=$?
set -e
assert_eq "137" "$RC" "код возврата процесса, убитого по пределу памяти cgroup"
journalctl -k --since "$SINCE" --no-pager -o cat | grep -q 'Memory cgroup out of memory: Killed process' \
  || fail "в журнале ядра нет записи о Memory cgroup out of memory"
systemctl reset-failed "$LAB_OOM_UNIT" 2>/dev/null || true
ok "предел cgroup: процесс убит (код 137), в журнале ядра «Memory cgroup out of memory»"

DEV="$(lab_swap_dev)"
if [[ -z "$DEV" ]]; then
  warn "раздела $LAB_SWAP_LABEL нет — проверку swap пропускаю (раздел создаётся руками в части 6)"
elif lab_swap_active; then
  [[ "$(meminfo_kb SwapTotal)" -gt 0 ]] || fail "раздел подключён, а SwapTotal равен нулю"
  ok "swap: $DEV уже подключён, SwapTotal $(meminfo_mib SwapTotal) МиБ"
else
  BEFORE="$(meminfo_kb SwapTotal)"
  swapon "$DEV"
  AFTER="$(meminfo_kb SwapTotal)"
  swapoff "$DEV"
  [[ "$AFTER" -gt "$BEFORE" ]] || fail "swapon $DEV не увеличил SwapTotal"
  assert_eq "$BEFORE" "$(meminfo_kb SwapTotal)" "SwapTotal после swapoff"
  ok "swap: swapon $DEV добавляет $(( (AFTER - BEFORE) / 1024 )) МиБ, swapoff возвращает как было"
fi

ok "module 03-memory verified"
