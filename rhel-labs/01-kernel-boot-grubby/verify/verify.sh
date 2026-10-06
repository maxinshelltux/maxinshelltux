#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=01-kernel-boot-grubby/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin grubby
need_bin grub2-editenv

ENTRIES="$(kernel_count)"
[[ "$ENTRIES" -ge 2 ]] || fail "нужно минимум два ядра (запусти сначала verify/prepare.sh)"

PRESENT="$(lab_params_in_config)"
[[ -z "$PRESENT" ]] \
  || refuse "в записях загрузчика уже есть параметры лабы ($PRESENT): сначала sudo ./verify/cleanup.sh"

START_DEFAULT="$(default_kernel)"
START_INDEX="$(default_index)"
NEWEST="$(newest_kernel)"
OLDEST="$(oldest_kernel)"
assert_ne "$NEWEST" "$OLDEST" "новое и старое ядро различаются"
if running_has_arg transparent_hugepage; then
  RUNNING_HAD_THP=1
else
  RUNNING_HAD_THP=0
fi

grubby --update-kernel=ALL --args="transparent_hugepage=never"
assert_eq "$ENTRIES" "$(entries_with_arg transparent_hugepage=never)" "--update-kernel=ALL добавил параметр во все записи"
ok "--update-kernel=ALL --args: transparent_hugepage=never в $ENTRIES записях из $ENTRIES"

kernel_cmdline_has transparent_hugepage=never \
  || fail "/etc/kernel/cmdline не получил параметр (новые ядра его не унаследуют)"
grub_default_has transparent_hugepage=never \
  || fail "GRUB_CMDLINE_LINUX в /etc/default/grub не получил параметр"
ok "ALL обновил и шаблоны: /etc/kernel/cmdline и GRUB_CMDLINE_LINUX"

if [[ "$RUNNING_HAD_THP" -eq 0 ]]; then
  if running_has_arg transparent_hugepage; then
    fail "/proc/cmdline изменился без перезагрузки — так не бывает"
  fi
  ok "до перезагрузки /proc/cmdline прежний: работающее ядро параметра не видит"
else
  warn "система уже загружена с transparent_hugepage — проверку «до перезагрузки» пропускаю"
fi

grubby --update-kernel=ALL --args="transparent_hugepage=madvise"
assert_eq "$ENTRIES" "$(entries_with_arg transparent_hugepage=madvise)" "повторный --args заменил значение"
assert_eq "0" "$(entries_with_arg transparent_hugepage=never)" "старое значение не осталось дублем"
ok "повторный --args с тем же ключом заменяет значение, а не дублирует"

grubby --update-kernel="$START_DEFAULT" --args="quiet"
assert_eq "1" "$(entries_with_arg quiet)" "параметр для одной записи попал только в неё"
entry_has_arg "$START_DEFAULT" quiet || fail "quiet не попал в запись $START_DEFAULT"
if kernel_cmdline_has quiet; then
  fail "правка одной записи изменила /etc/kernel/cmdline"
fi
ok "--update-kernel=<путь>: параметр только в одной записи, шаблоны не тронуты"

grubby --update-kernel=ALL --remove-args="transparent_hugepage quiet"
assert_eq "0" "$(entries_with_arg transparent_hugepage)" "--remove-args по ключу убрал параметр со значением"
assert_eq "0" "$(entries_with_arg quiet)" "--remove-args убрал quiet"
if kernel_cmdline_has transparent_hugepage; then
  fail "/etc/kernel/cmdline всё ещё содержит transparent_hugepage"
fi
ok "--remove-args по ключу убирает параметр вместе со значением, шаблоны очищены"

require_succeeds "удаление несуществующего параметра не ошибка" \
  grubby --update-kernel=ALL --remove-args="no_such_parameter"
ok "--remove-args несуществующего параметра завершается с кодом 0"

grubby --set-default "$OLDEST" >/dev/null 2>&1
assert_eq "$OLDEST" "$(default_kernel)" "--set-default сделал старое ядро ядром по умолчанию"
assert_eq "$(index_of_kernel "$OLDEST")" "$(default_index)" "--default-index указывает на ту же запись"
case "$(grubenv_value saved_entry)" in
  *"$(kernel_version "$OLDEST")") ;;
  *) fail "saved_entry в grubenv не указывает на $(kernel_version "$OLDEST")" ;;
esac
ok "--set-default <путь>: default-kernel, default-index и saved_entry согласованы"

grubby --set-default-index="$START_INDEX" >/dev/null 2>&1
assert_eq "$START_DEFAULT" "$(default_kernel)" "--set-default-index вернул исходное ядро"
ok "--set-default-index=$START_INDEX вернул исходное ядро по умолчанию"

require_fails "несуществующее ядро в --set-default" grubby --set-default /boot/vmlinuz-0.0.0
require_fails "несуществующий индекс в --set-default-index" grubby --set-default-index=99
assert_eq "$START_DEFAULT" "$(default_kernel)" "ошибочные команды не сменили ядро по умолчанию"
ok "ошибка в пути или индексе: код 1, ядро по умолчанию не меняется"

ok "module 01-kernel-boot-grubby verified"
