# Сценарий 01: «параметр модуля задан, а не действует»

Цели EX200 (RHEL 10), на которые опирается разбор: **Create and edit text files** и
**Use grep and regular expressions to analyze text**. Отдельной цели про модули ядра
в списке нет.

## Симптом
Нужны два интерфейса `dummy`. Модуль прописан в автозагрузку, параметр для пробы
записан во временный файл `/run/modprobe.d/lab-dummy.conf`. Модуль загружается,
интерфейсов нет.
```bash
sudo ./broken/scenario-01/make-broken.sh
# Заявка: «Нужны два интерфейса dummy. Прописал модуль в автозагрузку, а параметр
# numdummies=2 для пробы положил во временный /run/modprobe.d/lab-dummy.conf.
# Модуль загружается, а интерфейсов нет».
#
# Что видит автор заявки:
# # cat /run/modprobe.d/lab-dummy.conf
# options dummy numdummies=2
# # lsmod | grep dummy
# dummy                  12288  0
# # ip -br link show type dummy
# (пусто)
```

## Подсказки
1. Файл автора заявки в порядке. А что `modprobe` собрал из **всех** файлов?
2. Какую команду `modprobe` выполнит на самом деле? Спросите у него, не загружая
   модуль.
3. Если один параметр задан дважды, какое значение подействует?

## Диагностика
```bash
modprobe -c | grep -E '^(options|blacklist|install) dummy'
# options dummy numdummies=2
# options dummy numdummies=0

modprobe --show-depends dummy
# insmod /lib/modules/6.12.0-211.62.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz numdummies=2 numdummies=0 

grep -rn "dummy" /etc/modprobe.d/ /usr/lib/modprobe.d/ /run/modprobe.d/
# /usr/lib/modprobe.d/systemd.conf:18:# Do the same for dummy0.
# /usr/lib/modprobe.d/systemd.conf:20:options dummy numdummies=0
# /run/modprobe.d/lab-dummy.conf:1:options dummy numdummies=2
```
Параметр задан в двух местах. Вторую строку ставит пакет `systemd`, чтобы `dummy0`
не появлялся сам по себе. `man modprobe.d`: все options складываются вместе. Модуль
получает `numdummies=2 numdummies=0`, и действует последнее значение. Порядок
определяет имя файла, а не каталог: `lab-dummy.conf` идёт раньше `systemd.conf`.

`./run.sh` напоминает, что настройка временная:
```text
- настройки в /run/modprobe.d (/run/modprobe.d/lab-dummy.conf) действуют только до перезагрузки
[OK] dummy указан в автозагрузке (/etc/modules-load.d/dummy.conf) — будет загружен
```

## Решение
Задать параметр в файле, который по алфавиту идёт после `systemd.conf`
(см. `solutions/01-options-order/fix.sh`):
```bash
sudo ./solutions/01-options-order/fix.sh
# до исправления: modprobe выполнит «insmod /lib/modules/6.12.0-211.62.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz numdummies=2 numdummies=0 », интерфейсов dummy: 0
# options dummy numdummies=2
# options dummy numdummies=0
# options dummy numdummies=2
# dummy0           DOWN           ba:7a:36:7c:a0:00 <BROADCAST,NOARP> 
# dummy1           DOWN           6a:5e:e9:4b:97:50 <BROADCAST,NOARP> 
# [OK] numdummies=2 стоит последним и действует: интерфейсов dummy 2
# файл лежит в /run и после перезагрузки исчезнет; в /etc его не переносите — см. README, часть 3.3
```
Скрипт создаёт `/run/modprobe.d/zz-lab-dummy.conf` и перезагружает модуль. Старый
`lab-dummy.conf` он не трогает: строка из него идёт первой и ни на что не влияет.
Вручную то же самое —
`mv /run/modprobe.d/lab-dummy.conf /run/modprobe.d/zz-lab-dummy.conf`.

## Почему не в /etc
Автор заявки пробовал во временном каталоге не зря. На этом стенде постоянная
настройка `numdummies=2` приводит к тому, что интерфейс `dummy0` появляется при
старте раньше сети, и загрузка растягивается до пяти минут. Разбор с выводами — в
README, часть 3.3.

## Урок
Ваш файл в `modprobe.d` — только одно слагаемое. Проверяйте итог: `modprobe -c` и
`modprobe --show-depends <модуль>`.

После разбора верните стенд: `sudo ./verify/cleanup.sh` выгрузит модуль и обнулит
временные файлы в `/run`; файлы в `/etc` удаляет запуск с ключом `--apply`.
