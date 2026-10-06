#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=02-kernel-modules/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin modprobe
need_bin ip

QA_LOAD=/etc/modules-load.d/rhel-labs-qa.conf
QA_EARLY=/run/modprobe.d/rhel-labs-qa.conf
QA_LATE=/run/modprobe.d/zz-rhel-labs-qa.conf

BUSY="$(lab_files_with_content | tr '\n' ' ')"
[[ -z "${BUSY// /}" ]] \
  || refuse "в /etc уже есть настройки лабы (${BUSY% }): сначала sudo ./verify/cleanup.sh --apply"
if mod_loaded "$LAB_MODULE" || mod_loaded "$LAB_DEP_MODULE" || mod_loaded "$LAB_PARAM_MODULE"; then
  refuse "модуль лабы уже загружен ($LAB_MODULE, $LAB_DEP_MODULE или $LAB_PARAM_MODULE): сначала sudo ./verify/cleanup.sh"
fi
RUNTIME="$(run_files_with_content | tr '\n' ' ')"
[[ -z "${RUNTIME// /}" ]] \
  || refuse "в /run/modprobe.d лежат настройки лабы (${RUNTIME% }): они исчезнут после перезагрузки или обнулите их"
[[ -z "$(cmdline_blacklist)" ]] \
  || refuse "система загружена с modprobe.blacklist=$(cmdline_blacklist): сначала cleanup и перезагрузка"

reset_qa_files() {
  local file
  for file in "$QA_LOAD" "$QA_EARLY" "$QA_LATE"; do
    if [[ -e "$file" ]]; then
      : > "$file"
    fi
  done
}

finish() {
  unload_lab_modules
  reset_qa_files
  reload_autoload || true
}
trap finish EXIT

install -d /run/modprobe.d
reset_qa_files

HELPERS_BEFORE=0
for helper in $LAB_DEP_HELPERS; do
  if mod_loaded "$helper"; then
    HELPERS_BEFORE=1
  fi
done

modprobe "$LAB_MODULE"
mod_loaded "$LAB_MODULE" || fail "modprobe $LAB_MODULE не загрузил модуль"
assert_eq "0" "$(dummy_links)" "число dummy-интерфейсов при загрузке без параметров (numdummies=0 из systemd.conf)"
modprobe -r "$LAB_MODULE"
if mod_loaded "$LAB_MODULE"; then
  fail "modprobe -r $LAB_MODULE не выгрузил модуль"
fi
ok "modprobe / modprobe -r: модуль $LAB_MODULE загружается и выгружается"

modprobe "$LAB_MODULE" numdummies=2
assert_eq "2" "$(dummy_links)" "число dummy-интерфейсов при numdummies=2 в командной строке"
modprobe "$LAB_MODULE" numdummies=3
assert_eq "2" "$(dummy_links)" "повторный modprobe уже загруженного модуля ничего не меняет"
modprobe -r "$LAB_MODULE"
assert_eq "0" "$(dummy_links)" "после выгрузки интерфейсов не осталось"
ok "параметр в командной строке modprobe действует; повторная загрузка параметры не меняет"

modprobe "$LAB_PARAM_MODULE" rd_nr=2 rd_size=4096
assert_eq "2" "$(brd_param rd_nr)" "параметр rd_nr модуля $LAB_PARAM_MODULE в /sys/module"
assert_eq "4096" "$(brd_param rd_size)" "параметр rd_size модуля $LAB_PARAM_MODULE в /sys/module"
[[ -b /dev/ram0 && -b /dev/ram1 ]] || fail "после загрузки $LAB_PARAM_MODULE rd_nr=2 нет устройств /dev/ram0 и /dev/ram1"
modprobe -r "$LAB_PARAM_MODULE"
ok "параметры $LAB_PARAM_MODULE видны в /sys/module/$LAB_PARAM_MODULE/parameters: rd_nr=2, два RAM-диска"

require_fails "несуществующий модуль" modprobe no_such_module
if findmnt -n -t xfs / >/dev/null; then
  require_fails "выгрузка занятого модуля xfs" modprobe -r xfs
  ok "ошибки: несуществующий модуль и выгрузка занятого модуля завершаются отказом"
else
  warn "корень не на xfs — проверку «модуль занят» пропускаю"
fi

if [[ "$HELPERS_BEFORE" -eq 0 ]]; then
  modprobe "$LAB_DEP_MODULE"
  for helper in $LAB_DEP_HELPERS; do
    mod_loaded "$helper" || fail "modprobe $LAB_DEP_MODULE не подтянул зависимость $helper"
  done
  require_fails "выгрузка зависимости, которой пользуется $LAB_DEP_MODULE" rmmod udp_tunnel
  modprobe -r "$LAB_DEP_MODULE"
  for helper in $LAB_DEP_HELPERS; do
    if mod_loaded "$helper"; then
      fail "modprobe -r $LAB_DEP_MODULE оставил зависимость $helper"
    fi
  done
  ok "зависимости: modprobe $LAB_DEP_MODULE загружает и выгружает $LAB_DEP_HELPERS вместе с модулем"
else
  warn "зависимости $LAB_DEP_MODULE уже были загружены до проверки — проверку зависимостей пропускаю"
fi

echo "$LAB_MODULE" > "$QA_LOAD"
reload_autoload
mod_loaded "$LAB_MODULE" || fail "systemd-modules-load не загрузил $LAB_MODULE из $QA_LOAD"
modprobe -r "$LAB_MODULE"
ok "автозагрузка: systemd-modules-load читает modules-load.d и загружает модуль"

echo "options $LAB_MODULE numdummies=2" > "$QA_EARLY"
assert_eq "0" "$(last_option "$LAB_MODULE" numdummies)" "файл раньше systemd.conf по алфавиту: последним остаётся numdummies=0"
modprobe "$LAB_MODULE"
assert_eq "0" "$(dummy_links)" "параметр из раннего файла перебит systemd.conf"
modprobe -r "$LAB_MODULE"
: > "$QA_EARLY"
echo "options $LAB_MODULE numdummies=2" > "$QA_LATE"
assert_eq "2" "$(last_option "$LAB_MODULE" numdummies)" "файл позже systemd.conf по алфавиту: последним остаётся numdummies=2"
modprobe "$LAB_MODULE"
assert_eq "2" "$(dummy_links)" "параметр из позднего файла применился"
modprobe -r "$LAB_MODULE"
: > "$QA_LATE"
ok "параметры из modprobe.d: действует последнее значение, порядок задаёт имя файла"

echo "blacklist $LAB_MODULE" > "$QA_EARLY"
denylisted "$LAB_MODULE" || fail "modprobe -c не показывает blacklist $LAB_MODULE"
modprobe "$LAB_MODULE"
mod_loaded "$LAB_MODULE" || fail "одна строка blacklist не должна мешать явному modprobe"
modprobe -r "$LAB_MODULE"
reload_autoload
if mod_loaded "$LAB_MODULE"; then
  fail "systemd-modules-load загрузил модуль из списка запрета"
fi
ok "blacklist: автозагрузка модуль пропускает, явный modprobe всё ещё загружает"

printf 'blacklist %s\ninstall %s /bin/false\n' "$LAB_MODULE" "$LAB_MODULE" > "$QA_EARLY"
install_blocked "$LAB_MODULE" || fail "modprobe -c не показывает install $LAB_MODULE /bin/false"
require_fails "modprobe модуля с install /bin/false" modprobe "$LAB_MODULE"
if mod_loaded "$LAB_MODULE"; then
  fail "модуль загрузился вопреки install /bin/false"
fi
ok "blacklist + install /bin/false: modprobe завершается отказом, модуль не загружен"

reset_qa_files
reload_autoload
if mod_loaded "$LAB_MODULE"; then
  fail "после очистки проверочных файлов модуль $LAB_MODULE остался загруженным"
fi
assert_eq "options $LAB_MODULE numdummies=0" "$(effective_config "$LAB_MODULE")" "итоговая конфигурация $LAB_MODULE после проверки"
ok "проверочные файлы обнулены, конфигурация $LAB_MODULE исходная"

ok "module 02-kernel-modules verified"
