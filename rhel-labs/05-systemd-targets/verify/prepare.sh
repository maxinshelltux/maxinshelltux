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
  || refuse "ядро не выводит в последовательный порт: части rescue/emergency и инциденты рвут SSH, а без консоли систему не вернуть (README, «Как подготовлен стенд»)"

CONFIG_UNIT="$(lab_unit_in_config)"
[[ -z "$CONFIG_UNIT" ]] \
  || refuse "в записях загрузчика остался systemd.unit= ($(places_with_arg systemd.unit)): сначала уберите его — sudo ./verify/cleanup.sh"

install -d -m 700 "$LAB_STATE_DIR"
if [[ ! -f "$LAB_STATE_DIR/baseline.txt" ]]; then
  {
    echo "# снято $(date -u '+%F %T UTC')"
    echo "## systemctl get-default"
    default_target
    echo "## readlink -f /etc/systemd/system/default.target"
    readlink -f /etc/systemd/system/default.target
    echo "## /proc/cmdline"
    cat /proc/cmdline
    echo "## grubby --info=DEFAULT"
    grubby --info=DEFAULT
    echo "## systemctl is-system-running"
    system_state
  } > "$LAB_STATE_DIR/baseline.txt"
fi

ok "стенд готов: консоль $SERIAL, target по умолчанию $(default_target), снимок $LAB_STATE_DIR/baseline.txt"
