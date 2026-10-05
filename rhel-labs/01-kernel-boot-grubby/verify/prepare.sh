#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=01-kernel-boot-grubby/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin grubby
need_bin grub2-editenv
need_bin grub2-reboot
need_bin dnf
require_file /boot/loader/entries "каталог записей загрузчика (BLS)"
require_file /etc/kernel/cmdline "шаблон параметров для новых ядер"

if [[ "$(kernel_count)" -lt 2 ]]; then
  echo "установлено одно ядро, ставлю обновление: dnf upgrade kernel"
  dnf -y -q upgrade kernel
fi

[[ "$(kernel_count)" -ge 2 ]] \
  || fail "нужно минимум два ядра, а в репозитории нет более нового: поставь конкретную версию (dnf install kernel-<версия>)"

install -d -m 700 "$LAB_STATE_DIR"
if [[ ! -f "$LAB_STATE_DIR/baseline.txt" ]]; then
  {
    echo "# снято $(date -u '+%F %T UTC')"
    echo "## uname -r"
    uname -r
    echo "## grubby --default-kernel"
    default_kernel
    echo "## grubby --info=ALL"
    grubby --info=ALL
    echo "## /proc/cmdline"
    cat /proc/cmdline
    echo "## /etc/kernel/cmdline"
    cat /etc/kernel/cmdline
    echo "## grub2-editenv list"
    grub2-editenv list
  } > "$LAB_STATE_DIR/baseline.txt"
fi

ok "стенд готов: ядер $(kernel_count), по умолчанию $(default_kernel), снимок $LAB_STATE_DIR/baseline.txt"
