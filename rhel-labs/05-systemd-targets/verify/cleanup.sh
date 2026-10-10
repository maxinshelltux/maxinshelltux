#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=05-systemd-targets/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin systemctl
need_bin grubby

CONFIG_UNIT="$(lab_unit_in_config)"
if [[ -n "$CONFIG_UNIT" ]]; then
  WHERE="$(places_with_arg systemd.unit)"
  remove_lab_keys
  LEFT="$(lab_unit_in_config)"
  [[ -z "$LEFT" ]] || fail "systemd.unit= остался в записях: $LEFT"
  ok "из записей загрузчика убран systemd.unit= (был в: $WHERE)"
else
  ok "в записях загрузчика нет systemd.unit="
fi

DEFAULT_PROBLEM="$(default_target_problem)"
if [[ -n "$DEFAULT_PROBLEM" ]]; then
  systemctl set-default "$BASELINE_TARGET" >/dev/null
  ok "target по умолчанию возвращён на $BASELINE_TARGET (было: $DEFAULT_PROBLEM)"
else
  ok "target по умолчанию уже $BASELINE_TARGET"
fi

RUNNING_UNIT="$(lab_unit_in_running)"
if [[ -n "$RUNNING_UNIT" ]]; then
  warn "система сейчас загружена с разовым systemd.unit= — перезагрузись: systemctl reboot"
fi

if [[ "$(target_active rescue.target)" == "active" ]]; then
  warn "система сейчас в rescue.target — вернуться: systemctl default (или перезагрузиться)"
fi

STATE="$(system_state)"
[[ "$STATE" == "running" ]] || warn "is-system-running: $STATE"

ok "cleanup 05-systemd-targets"
