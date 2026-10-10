#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=05-systemd-targets/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin systemctl
need_bin systemd-analyze
need_bin grubby

SERIAL="$(serial_console)"
[[ -n "$SERIAL" ]] \
  || fail "среди консолей ядра нет последовательного порта: rescue/emergency из этой лабы будет некому вернуть"
ok "ядро пишет в последовательный порт ($SERIAL): rescue/emergency из лабы восстановимы с консоли"

CORE_PROBLEM="$(core_target_problems)"
[[ -z "$CORE_PROBLEM" ]] || fail "не загружены нужные target: $CORE_PROBLEM"
ok "target загружены: $CORE_TARGETS"

ISO_PROBLEM="$(isolate_problems)"
[[ -z "$ISO_PROBLEM" ]] || fail "target не допускают isolate (AllowIsolate=no): $ISO_PROBLEM"
ok "multi-user/graphical/rescue/emergency допускают isolate (AllowIsolate=yes)"

DEFAULT_PROBLEM="$(default_target_problem)"
[[ -z "$DEFAULT_PROBLEM" ]] || fail "$DEFAULT_PROBLEM (вернуть: systemctl set-default $BASELINE_TARGET)"
ok "target по умолчанию $BASELINE_TARGET и симлинк default.target ведёт туда же"

CONFIG_UNIT="$(lab_unit_in_config)"
[[ -z "$CONFIG_UNIT" ]] \
  || fail "в записях загрузчика остался systemd.unit= ($(places_with_arg systemd.unit)): sudo ./verify/cleanup.sh"
ok "в записях загрузчика нет systemd.unit="

RUNNING_UNIT="$(lab_unit_in_running)"
[[ -z "$RUNNING_UNIT" ]] \
  || fail "система сейчас загружена с разовым systemd.unit= в /proc/cmdline — перезагрузись без правки"
ok "текущая загрузка прошла без разового systemd.unit="

assert_eq "active" "$(target_active "$BASELINE_TARGET")" "$BASELINE_TARGET"
assert_eq "inactive" "$(target_active rescue.target)" "rescue.target"
ok "система в $BASELINE_TARGET, не в rescue/emergency"

TOTAL="$(analyze_total)"
[[ -n "$TOTAL" ]] || fail "systemd-analyze не отдал время загрузки: нечего анализировать"
ok "systemd-analyze читает прошлую загрузку: $TOTAL"
echo "     дольше всех: $(slowest_unit)"

STATE="$(system_state)"
case "$STATE" in
  running) ok "is-system-running: running" ;;
  degraded)
    warn "is-system-running: degraded — есть упавшие юниты:"
    failed_units | sed 's/^/     /' ;;
  *) warn "is-system-running: $STATE" ;;
esac

ok "module 05-systemd-targets verified"
