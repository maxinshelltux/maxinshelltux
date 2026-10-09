#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=04-boot-interrupt-rd-break/lib.sh
source "$MODULE_DIR/lib.sh"

MODE=dry-run
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "usage: $0 [--apply]"; exit 2 ;;
esac

need_root
need_bin chcon

echo "Инцидент: пароль root сброшен через rd.break, но забыт touch /.autorelabel."
echo "Симптом воспроизводится неверной меткой /etc/shadow (user_tmp_t вместо shadow_t)."
echo
echo "ВНИМАНИЕ: после применения вход по SSH и sudo перестают работать."
echo "Вернуть систему можно только с консоли стенда (rd.break). Запускайте с ментором"
echo "и при открытой консоли."
echo

if [[ "$MODE" == dry-run ]]; then
  echo "текущая метка:"
  ls -Z /etc/shadow
  echo
  echo "[DRY-RUN] был бы выполнен: chcon -t user_tmp_t /etc/shadow"
  echo "применить: sudo $0 --apply"
  exit 0
fi

echo "текущая метка:"
ls -Z /etc/shadow
chcon -t user_tmp_t /etc/shadow
echo "после правки:"
ls -Z /etc/shadow
echo
echo "Теперь попробуйте войти под root в консоли или зайти по SSH заново — не пустит."
echo "разбор: broken/scenario-01/README.md · фикс: solutions/01-shadow-relabel/README.md"
