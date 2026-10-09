#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin grubby
need_bin grub2-editenv
need_bin lsinitrd
need_bin getenforce
need_bin restorecon
require_file "$GRUB_DEFAULTS" "настройки GRUB"
require_file "$GRUB_CFG" "конфигурация GRUB"

SERIAL="$(serial_console)"
[[ -n "$SERIAL" ]] \
  || fail "ядро не выводит сообщения в последовательный порт (нет console=ttyS… в /proc/cmdline): без консоли лаба невыполнима"

MENU_PROBLEM="$(grub_menu_problem)"
[[ -z "$MENU_PROBLEM" ]] \
  || fail "$MENU_PROBLEM — стенд готовит ментор: README, «Как подготовлен стенд»"

install -d -m 700 "$LAB_STATE_DIR"
if [[ ! -f "$LAB_STATE_DIR/baseline.txt" ]]; then
  {
    echo "# снято $(date -u '+%F %T UTC')"
    echo "## uname -r"
    uname -r
    echo "## /proc/cmdline"
    cat /proc/cmdline
    echo "## grubby --info=DEFAULT"
    grubby --info=DEFAULT
    echo "## $GRUB_DEFAULTS"
    cat "$GRUB_DEFAULTS"
    echo "## grub2-editenv list"
    grub2-editenv list
    echo "## getenforce"
    getenforce
    echo "## ls -Z /etc/shadow"
    ls -Z /etc/shadow
    echo "## passwd -S root"
    passwd -S root
  } > "$LAB_STATE_DIR/baseline.txt"
fi

ok "стенд готов: консоль $SERIAL, меню GRUB ждёт $(grub_cfg_timeout) с, пароль root $(root_password_words), снимок $LAB_STATE_DIR/baseline.txt"
