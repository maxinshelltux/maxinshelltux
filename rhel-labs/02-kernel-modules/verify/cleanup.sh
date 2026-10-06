#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=02-kernel-modules/lib.sh
source "$MODULE_DIR/lib.sh"

MODE=dry-run
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "usage: $0 [--apply]"; exit 2 ;;
esac

need_root
need_bin modprobe
need_bin grubby

unload_lab_modules
if mod_loaded "$LAB_MODULE"; then
  fail "модуль $LAB_MODULE не выгрузился: занят ($(mod_users "$LAB_MODULE"))"
fi
if mod_loaded "$LAB_PARAM_MODULE"; then
  fail "модуль $LAB_PARAM_MODULE не выгрузился: занят ($(mod_users "$LAB_PARAM_MODULE"))"
fi
ok "модули лабы выгружены: $LAB_MODULE, $LAB_PARAM_MODULE, $LAB_DEP_MODULE"

if [[ "$(boot_entries_with_lab_arg)" -gt 0 ]]; then
  grubby --update-kernel=ALL --remove-args="$LAB_KERNEL_ARG"
  ok "параметр $LAB_KERNEL_ARG убран из записей загрузчика"
fi

PRESENT=0
REMOVED=0
for file in "${LAB_FILES[@]}"; do
  [[ -e "$file" || -L "$file" ]] || continue
  PRESENT=$((PRESENT + 1))
  SIZE="$(stat -c %s "$file")"
  if [[ "$MODE" == dry-run ]]; then
    echo "[DRY-RUN] был бы удалён: $file ($SIZE байт, $(lab_file_state "$file"))"
    continue
  fi
  lab_file_is_lab_owned "$file" \
    || fail "в $file есть строки не из лабы — файл не трогаю, разберись вручную"
  rm -f -- "$file"
  REMOVED=$((REMOVED + 1))
  echo "[APPLY] удалён: $file ($SIZE байт)"
done

if [[ "$MODE" == dry-run ]]; then
  if [[ "$PRESENT" -gt 0 ]]; then
    warn "файлов лабы на месте: $PRESENT; удаляет их только запуск с ключом: sudo ./verify/cleanup.sh --apply"
  else
    ok "файлов лабы в /etc нет"
  fi
else
  ok "удалено файлов лабы: $REMOVED"
fi

for file in "${LAB_RUN_FILES[@]}"; do
  [[ -s "$file" ]] || continue
  lab_file_is_lab_owned "$file" \
    || fail "в $file есть строки не из лабы — файл не трогаю, разберись вручную"
  : > "$file"
  ok "временный файл обнулён: $file"
done

if [[ -n "$(cmdline_blacklist)" ]]; then
  warn "система загружена с modprobe.blacklist=$(cmdline_blacklist) — перезагрузись: systemctl reboot"
fi

ok "cleanup 02-kernel-modules ($MODE)"
