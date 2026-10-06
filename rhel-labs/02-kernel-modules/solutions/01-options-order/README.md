# Решение сценария 01: параметр перебит системным файлом

Инцидент: `broken/scenario-01/`. Строка `options dummy numdummies=2` лежит в
`/run/modprobe.d/lab-dummy.conf`, а `/usr/lib/modprobe.d/systemd.conf` добавляет
после неё `numdummies=0`.

`fix.sh` записывает тот же параметр в файл, который идёт позже по алфавиту,
перезагружает модуль и проверяет результат:

```bash
echo "options dummy numdummies=2" > /run/modprobe.d/zz-lab-dummy.conf
modprobe -r dummy; modprobe dummy
```

Файл остаётся во временном каталоге `/run` и после перезагрузки исчезает. Переносить
его в `/etc` на этом стенде нельзя: интерфейсы `dummy`, появившиеся при старте,
растягивают загрузку до пяти минут (README, часть 3.3).
