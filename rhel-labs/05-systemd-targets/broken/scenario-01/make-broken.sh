#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=05-systemd-targets/lib.sh
source "$MODULE_DIR/lib.sh"

MODE=dry-run
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "usage: $0 [--apply]"; exit 2 ;;
esac

need_root
need_bin systemctl

echo "Инцидент: кто-то сделал target по умолчанию rescue.target вместо multi-user.target."
echo
echo "ВНИМАНИЕ: после перезагрузки система уйдёт в rescue — без сети и SSH."
echo "Вернуть можно только с консоли стенда. Запускайте с ментором и при открытой консоли."
echo

if [[ "$MODE" == dry-run ]]; then
  echo "сейчас target по умолчанию: $(default_target)"
  echo
  echo "[DRY-RUN] был бы выполнен: systemctl set-default rescue.target"
  echo "применить: sudo $0 --apply"
  exit 0
fi

echo "было: $(default_target)"
systemctl set-default rescue.target
echo "стало: $(default_target)"
echo
echo "Перезагрузись (systemctl reboot) и воспроизведи симптом с консоли."
echo "разбор: broken/scenario-01/README.md · фикс: solutions/01-default-target/fix.sh"
