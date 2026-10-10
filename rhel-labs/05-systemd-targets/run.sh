#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=05-systemd-targets/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin systemctl
need_bin systemd-analyze
need_bin grubby

echo "=== Текущее состояние ==="
echo "is-system-running:  $(system_state)"
echo "target по умолчанию: $(default_target)"
echo "default.target ->    $(readlink -f /etc/systemd/system/default.target)"
echo "runlevel:            $(who -r | sed 's/^ *//')"
DEFAULT_PROBLEM="$(default_target_problem)"
if [[ -z "$DEFAULT_PROBLEM" ]]; then
  ok "target по умолчанию $BASELINE_TARGET, как в исходном образе"
else
  warn "$DEFAULT_PROBLEM"
fi
echo

echo "=== Активные target ==="
systemctl list-units --type=target --state=active --no-legend --plain | awk '{ printf "  %s\n", $1 }'
echo "multi-user.target:   $(target_active multi-user.target)"
echo "graphical.target:    $(target_active graphical.target)"
echo "rescue.target:       $(target_active rescue.target)"
echo

echo "=== Можно ли переключаться (AllowIsolate) ==="
for t in $CORE_TARGETS basic.target; do
  printf '  %-20s AllowIsolate=%s\n' "$t" "$(allow_isolate "$t")"
done
ISO_PROBLEM="$(isolate_problems)"
if [[ -n "$ISO_PROBLEM" ]]; then
  warn "не допускают isolate (а должны): $ISO_PROBLEM"
fi
echo

echo "=== Параметр systemd.unit в загрузке ==="
echo "/proc/cmdline: $(cat /proc/cmdline)"
RUNNING_UNIT="$(lab_unit_in_running)"
CONFIG_UNIT="$(lab_unit_in_config)"
if [[ -n "$RUNNING_UNIT" ]]; then
  warn "система загружена с разовым systemd.unit= в командной строке ядра (перекрывает target по умолчанию)"
fi
if [[ -n "$CONFIG_UNIT" ]]; then
  warn "systemd.unit= прописан в записях загрузчика: $(places_with_arg systemd.unit) — будет применяться при каждой загрузке"
else
  ok "в записях загрузчика нет systemd.unit="
fi
echo

echo "=== Анализ загрузки ==="
analyze_total
echo "дольше всех поднимался: $(slowest_unit)"
echo

echo "=== Проблемные юниты ==="
FAILED="$(failed_units)"
if [[ -n "$FAILED" ]]; then
  warn "есть failed-юниты:"
  while IFS= read -r unit; do
    echo "     $unit"
  done <<< "$FAILED"
else
  ok "failed-юнитов нет"
fi
