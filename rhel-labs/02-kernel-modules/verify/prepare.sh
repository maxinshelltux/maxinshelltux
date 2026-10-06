#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=02-kernel-modules/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
for bin in lsmod modinfo modprobe rmmod insmod lsinitrd grubby ip systemctl; do
  need_bin "$bin"
done
require_file "/lib/modules/$(uname -r)/modules.dep" "карта зависимостей модулей работающего ядра"
[[ -n "$(mod_file "$LAB_MODULE")" ]] || fail "нет модуля $LAB_MODULE для ядра $(uname -r) (пакет kernel-modules-core)"
[[ -n "$(mod_file "$LAB_DEP_MODULE")" ]] || fail "нет модуля $LAB_DEP_MODULE для ядра $(uname -r) (пакет kernel-modules-core)"
[[ -n "$(mod_file "$LAB_PARAM_MODULE")" ]] || fail "нет модуля $LAB_PARAM_MODULE для ядра $(uname -r) (пакет kernel-modules-core)"
require_succeeds "сервис автозагрузки модулей" systemctl cat systemd-modules-load.service

if ! grep -qsxE 'options dummy numdummies=0' /usr/lib/modprobe.d/systemd.conf; then
  warn "в /usr/lib/modprobe.d/systemd.conf нет 'options dummy numdummies=0' — часть 3 и инцидент 1 будут выглядеть иначе"
fi

install -d -m 700 "$LAB_STATE_DIR"
if [[ ! -f "$LAB_STATE_DIR/baseline.txt" ]]; then
  {
    echo "# снято $(date -u '+%F %T UTC')"
    echo "## uname -r"
    uname -r
    echo "## lsmod"
    lsmod
    echo "## modprobe -c: строки про $LAB_MODULE"
    effective_config "$LAB_MODULE"
    echo "## /etc/modules-load.d /etc/modprobe.d"
    ls -l /etc/modules-load.d /etc/modprobe.d
    echo "## /proc/cmdline"
    cat /proc/cmdline
  } > "$LAB_STATE_DIR/baseline.txt"
fi

ok "стенд готов: ядро $(uname -r), модулей загружено $(($(lsmod | wc -l) - 1)), $LAB_MODULE загружен: $(mod_loaded "$LAB_MODULE" && echo да || echo нет), снимок $LAB_STATE_DIR/baseline.txt"
