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
echo "до исправления: modprobe выполнит «$(modprobe --show-depends "$LAB_MODULE" | tail -n 1)», интерфейсов dummy: $(dummy_links)"
install -d /run/modprobe.d
echo "options $LAB_MODULE numdummies=2" > /run/modprobe.d/zz-lab-dummy.conf
if mod_loaded "$LAB_MODULE"; then
  modprobe -r "$LAB_MODULE"
fi
modprobe "$LAB_MODULE"
modprobe -c | grep -E "^options $LAB_MODULE "
assert_eq "2" "$(last_option "$LAB_MODULE" numdummies)" "последнее значение numdummies в итоговой конфигурации"
assert_eq "2" "$(dummy_links)" "число интерфейсов dummy после перезагрузки модуля"
ip -br link show type dummy
ok "numdummies=2 стоит последним и действует: интерфейсов dummy $(dummy_links)"
echo "файл лежит в /run и после перезагрузки исчезнет; в /etc его не переносите — см. README, часть 3.3"
