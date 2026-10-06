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
install -d /run/modprobe.d
if [[ -e /run/modprobe.d/zz-lab-dummy.conf ]]; then
  : > /run/modprobe.d/zz-lab-dummy.conf
fi
echo "options $LAB_MODULE numdummies=2" > /run/modprobe.d/lab-dummy.conf
reload_autoload

echo "Заявка: «Нужны два интерфейса dummy. Прописал модуль в автозагрузку, а параметр"
echo "numdummies=2 для пробы положил во временный /run/modprobe.d/lab-dummy.conf."
echo "Модуль загружается, а интерфейсов нет»."
echo
echo "Что видит автор заявки:"
echo "# cat /run/modprobe.d/lab-dummy.conf"
cat /run/modprobe.d/lab-dummy.conf
echo "# lsmod | grep dummy"
lsmod | grep dummy || true
echo "# ip -br link show type dummy"
ip -br link show type dummy
echo "(пусто)"
echo
echo "разбор: broken/scenario-01/README.md · фикс: solutions/01-options-order/fix.sh"
