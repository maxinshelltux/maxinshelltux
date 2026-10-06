# 02 — Модуль с параметром при каждой загрузке

## Цель экзамена
В списке целей EX200 (RHEL 10) отдельной цели про модули ядра нет. Задание опирается
на цели: **Create and edit text files** (*Understand and use essential tools*),
**Start and stop services and configure services to start automatically at boot**
(*Deploy, configure, and maintain systems*) и **Boot, reboot, and shut down a system
normally** (*Operate running systems*). Общее требование экзамена: настройка должна
сохраняться после перезагрузки без вмешательства.
Команды — из раздела 3.9 руководства RHEL 10 и `man modprobe.d`.

## Задача
Настройте систему так, чтобы после каждой перезагрузки без вашего участия:

1. модуль `brd` был загружен;
2. он создавал ровно **два** RAM-диска по 4 МиБ (параметры `rd_nr=2`,
   `rd_size=4096`).

## Проверка
```bash
# до перезагрузки: что прочитает служба автозагрузки и что соберёт modprobe
cat /etc/modules-load.d/brd.conf
modprobe -c | grep -E '^options brd'
modprobe --show-depends brd

systemctl reboot

# после перезагрузки
lsmod | grep '^brd '
cat /sys/module/brd/parameters/rd_nr
lsblk /dev/ram0 /dev/ram1
journalctl -b -t systemd-modules-load --no-pager -o cat | grep brd
```

## Ожидаемый результат
До перезагрузки:
```
brd

options brd rd_nr=2 rd_size=4096

insmod /lib/modules/6.12.0-211.62.1.el10_2.x86_64/kernel/drivers/block/brd.ko.xz rd_nr=2 rd_size=4096 
```
После перезагрузки:
```
brd                    16384  0

2

NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
ram0   1:0    0   4M  0 disk 
ram1   1:1    0   4M  0 disk 

Inserted module 'brd'
```
(версия ядра в пути у вас своя). Модуль загружен службой автозагрузки, параметр
`rd_nr` равен 2, дисков ровно два.

Решение:
```bash
echo brd > /etc/modules-load.d/brd.conf
echo "options brd rd_nr=2 rd_size=4096" > /etc/modprobe.d/brd.conf
systemctl reboot
```
Проверить файлы без перезагрузки можно командой `systemctl restart
systemd-modules-load.service`. Разбор — README, части 3.4 и 3.5.

Не повторяйте это задание с модулем `dummy` и параметром `numdummies`: на этом
стенде интерфейсы `dummy`, появившиеся при старте, растягивают загрузку до пяти
минут (README, часть 3.3).
