#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby

echo "Заявка: «После восстановления системы заметил, что SELinux в permissive, хотя в"
echo "/etc/selinux/config стоит enforcing»."
echo
echo "Что сделал автор заявки (добавил enforcing=0 во все записи вместо разовой правки):"
echo "# grubby --update-kernel=ALL --args=enforcing=0"
grubby --update-kernel=ALL --args="enforcing=0"
echo
echo "Сейчас в записи по умолчанию:"
grubby --info=DEFAULT | grep ^args
echo
echo "Перезагрузись (systemctl reboot) и воспроизведи симптом:"
echo "  getenforce"
echo "  grep ^SELINUX= /etc/selinux/config"
echo
echo "разбор: broken/scenario-02/README.md · фикс: solutions/02-remove-enforcing/fix.sh"
