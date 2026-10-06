#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=02-kernel-modules/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin modprobe
need_bin ip

echo "=== Ядро и модули ==="
echo "uname -r:           $(uname -r)"
echo "загружено модулей:  $(($(lsmod | wc -l) - 1))"
echo "файлов модулей:     $(find "/lib/modules/$(uname -r)" -name '*.ko*' | wc -l)"
echo

echo "=== Модули лабы сейчас ==="
for module in "$LAB_MODULE" "$LAB_PARAM_MODULE" "$LAB_DEP_MODULE" $LAB_DEP_HELPERS; do
  if mod_loaded "$module"; then
    printf '%-16s загружен, кем занят: %s\n' "$module" "$(mod_users "$module")"
  else
    printf '%-16s не загружен\n' "$module"
  fi
done
echo "интерфейсов dummy:  $(dummy_links)"
if mod_loaded "$LAB_PARAM_MODULE"; then
  echo "параметры $LAB_PARAM_MODULE:      rd_nr=$(brd_param rd_nr) rd_size=$(brd_param rd_size)"
fi
echo

echo "=== Итоговая конфигурация modprobe для $LAB_MODULE (modprobe -c) ==="
CONFIG="$(effective_config "$LAB_MODULE")"
echo "${CONFIG:-<строк нет>}"
echo "что выполнит modprobe: $(modprobe --show-depends "$LAB_MODULE" 2>&1 | tail -n 1)"
echo

echo "=== Итоговая конфигурация modprobe для $LAB_PARAM_MODULE ==="
CONFIG="$(effective_config "$LAB_PARAM_MODULE")"
echo "${CONFIG:-<строк нет>}"
echo

echo "=== Файлы лабы ==="
for file in "${LAB_FILES[@]}" "${LAB_RUN_FILES[@]}"; do
  printf '%-40s %s\n' "$file" "$(lab_file_state "$file")"
done
echo

echo "=== Что будет при следующей загрузке ==="
RUNTIME="$(run_files_with_content | tr '\n' ' ')"
if [[ -n "${RUNTIME// /}" ]]; then
  echo "- настройки в /run/modprobe.d (${RUNTIME% }) действуют только до перезагрузки"
fi
PARAM_LISTED="$(autoload_files "$LAB_PARAM_MODULE" | tr '\n' ' ')"
if [[ -n "${PARAM_LISTED// /}" ]]; then
  ok "$LAB_PARAM_MODULE указан в автозагрузке (${PARAM_LISTED% }), параметры: $(effective_options "$LAB_PARAM_MODULE") — будет загружен"
fi
LISTED="$(autoload_files "$LAB_MODULE" | tr '\n' ' ')"
if [[ -n "$(cmdline_blacklist)" ]]; then
  echo "- сейчас система загружена с modprobe.blacklist=$(cmdline_blacklist)"
fi
if [[ "$(boot_entries_with_lab_arg)" -gt 0 ]]; then
  echo "- в записях загрузчика есть $LAB_KERNEL_ARG (записей: $(boot_entries_with_lab_arg))"
fi
if [[ -z "${LISTED// /}" ]]; then
  ok "$LAB_MODULE в автозагрузке не указан — после перезагрузки загружен не будет"
elif install_blocked "$LAB_MODULE" || denylisted "$LAB_MODULE" || [[ "$(boot_entries_with_lab_arg)" -gt 0 ]]; then
  warn "$LAB_MODULE указан в автозагрузке (${LISTED% }), но запрещён — загружен не будет"
else
  ok "$LAB_MODULE указан в автозагрузке (${LISTED% }) — будет загружен"
fi
