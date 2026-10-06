#!/usr/bin/env bash
set -uo pipefail

TARGET="${1:-}"
[[ -n "$TARGET" ]] || { echo "usage: $0 <NN-module>"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT_DIR/$TARGET"
[[ -d "$DIR" ]] || { echo "нет каталога модуля: $DIR"; exit 1; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[FAIL] нужен root: sudo $0 $TARGET" >&2
  exit 1
fi

CLEANED=0
# shellcheck disable=SC2317
do_cleanup() {
  [[ "$CLEANED" == 1 ]] && return 0
  CLEANED=1
  if [[ -x "$DIR/verify/cleanup.sh" ]]; then
    bash "$DIR/verify/cleanup.sh" || true
  fi
}
trap do_cleanup EXIT
trap 'exit 124' TERM INT

echo "--- module: $TARGET ---"

[[ -f "$DIR/verify/verify.sh" ]] || { echo "[FAIL] у модуля нет verify/verify.sh"; exit 1; }

if [[ -f "$DIR/verify/prepare.sh" ]]; then
  echo "prepare..."
  bash "$DIR/verify/prepare.sh" || { echo "[FAIL] prepare.sh упал"; exit 1; }
fi
echo "verify..."
bash "$DIR/verify/verify.sh"
STATUS=$?
if [[ "$STATUS" -eq 3 ]]; then
  CLEANED=1
  echo "[WARN] проверка не начата: состояние стенда оставлено как есть, cleanup не запускался"
fi
exit "$STATUS"
