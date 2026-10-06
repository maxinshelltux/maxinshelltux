#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

command -v shellcheck >/dev/null 2>&1 || { echo "[FAIL] не найден shellcheck"; exit 1; }

status=0
while IFS= read -r -d '' script; do
  if shellcheck -x "$script"; then
    echo "[OK] shellcheck $script"
  else
    echo "[FAIL] shellcheck $script"
    status=1
  fi
done < <(find . -name '*.sh' -print0 | sort -z)

while IFS= read -r -d '' program; do
  if python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$program"; then
    echo "[OK] python $program"
  else
    echo "[FAIL] python $program"
    status=1
  fi
done < <(find . -name '*.py' -print0 | sort -z)

for readme in */README.md; do
  module="${readme%/README.md}"
  [[ -f "$module/verify/verify.sh" ]] || continue
  if grep -q '<!-- TOC -->' "$readme" && grep -q '^> ⏱' "$readme"; then
    echo "[OK] markdown $readme"
  else
    echo "[FAIL] markdown $readme: нужны маркеры <!-- TOC --> и строка > ⏱"
    status=1
  fi
done

exit "$status"
