#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=02-kernel-modules/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin modprobe
need_bin ip
BUSY="$(lab_files_with_content | tr '\n' ' ')"
[[ -z "${BUSY// /}" ]] || fail "в /etc уже есть настройки лабы (${BUSY% }): сначала sudo ./verify/cleanup.sh --apply"

unload_lab_modules
echo "$LAB_MODULE" > /etc/modules-load.d/dummy.conf
echo "blacklist $LAB_MODULE" > /etc/modprobe.d/lab-denylist.conf
reload_autoload

echo "Заявка: «Прописал dummy в автозагрузку, а после перезагрузки модуля нет."
echo "При этом руками modprobe dummy отрабатывает без единой ошибки»."
echo
echo "Что видит автор заявки:"
echo "# cat /etc/modules-load.d/dummy.conf"
cat /etc/modules-load.d/dummy.conf
echo "# systemctl is-active systemd-modules-load.service"
systemctl is-active systemd-modules-load.service || true
echo "# lsmod | grep dummy"
lsmod | grep dummy || echo "(пусто)"
echo
echo "разбор: broken/scenario-02/README.md · фикс: solutions/02-denylisted-autoload/fix.sh"
