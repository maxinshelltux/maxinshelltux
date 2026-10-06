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
echo "до исправления: $LAB_MODULE загружен: $(mod_loaded "$LAB_MODULE" && echo да || echo нет)"
echo "что запрещает загрузку:"
grep -rnE "^(blacklist|install) $LAB_MODULE( |$)" /etc/modprobe.d /run/modprobe.d /usr/lib/modprobe.d || true
sed -i -E "/^(blacklist $LAB_MODULE|install $LAB_MODULE \/bin\/false)$/d" /etc/modprobe.d/lab-denylist.conf
if denylisted "$LAB_MODULE" || install_blocked "$LAB_MODULE"; then
  fail "запрет на $LAB_MODULE задан где-то ещё: modprobe -c | grep $LAB_MODULE"
fi
reload_autoload
mod_loaded "$LAB_MODULE" || fail "systemd-modules-load не загрузил $LAB_MODULE: journalctl -b -u systemd-modules-load"
lsmod | grep "^$LAB_MODULE "
ok "запрет снят, $LAB_MODULE загружен службой автозагрузки"
echo "осталось перезагрузиться и проверить: lsmod | grep dummy"
