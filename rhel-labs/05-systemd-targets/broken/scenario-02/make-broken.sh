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
need_bin grubby

echo "Инцидент: systemd.unit=rescue.target дописали во все записи загрузчика через grubby."
echo "target по умолчанию при этом остаётся multi-user.target — симптом коварный."
echo
echo "ВНИМАНИЕ: после перезагрузки система уйдёт в rescue — без сети и SSH."
echo "Вернуть можно только с консоли стенда. Запускайте с ментором и при открытой консоли."
echo

if [[ "$MODE" == dry-run ]]; then
  PLACES="$(places_with_arg systemd.unit)"
  echo "сейчас systemd.unit= в записях: ${PLACES:-нет}"
  echo
  echo "[DRY-RUN] был бы выполнен: grubby --update-kernel=ALL --args=systemd.unit=rescue.target"
  echo "применить: sudo $0 --apply"
  exit 0
fi

grubby --update-kernel=ALL --args="systemd.unit=rescue.target"
echo "теперь в записи по умолчанию:"
grubby --info=DEFAULT | grep ^args
echo
echo "Перезагрузись (systemctl reboot) и воспроизведи симптом с консоли."
echo "разбор: broken/scenario-02/README.md · фикс: solutions/02-remove-systemd-unit/fix.sh"
