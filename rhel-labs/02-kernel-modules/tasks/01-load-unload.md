# 01 — Изучить, загрузить с параметром, выгрузить с зависимостями

## Цель экзамена
В списке целей EX200 (RHEL 10) отдельной цели про модули ядра нет. Задание опирается
на цели раздела *Understand and use essential tools*:
**Locate, read, and use system documentation including man, info, and files in
/usr/share/doc** и **Use grep and regular expressions to analyze text**.
Команды — из разделов 3.4–3.7 руководства RHEL 10 «Managing, monitoring, and
updating the kernel».

## Задача
1. Выясните для модуля `dummy`: загружен ли он, из какого файла загружается, какие
   параметры принимает.
2. Загрузите `dummy` так, чтобы в системе появилось **три** интерфейса типа dummy.
   Докажите.
3. Выгрузите `dummy`.
4. Загрузите модуль `vxlan`, назовите модули, которые загрузились вместе с ним, и
   выгрузите все три одной командой.

Настройка в этом задании нужна только на текущий сеанс — файлы в `/etc` не трогаем.

## Проверка
```bash
# шаг 1
lsmod | grep dummy
modinfo -n dummy
modinfo -p dummy

# шаг 2
ip -br link show type dummy | wc -l

# шаг 3
lsmod | grep dummy

# шаг 4, после загрузки и после выгрузки
lsmod | grep -E '^(vxlan|udp_tunnel|ip6_udp_tunnel) '
```

## Ожидаемый результат
Шаг 1 (первая команда ничего не печатает — модуль не загружен):
```
/lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz
numdummies:Number of dummy pseudo devices (int)
```
Шаг 2:
```
3
```
Шаг 3: вывода нет.

Шаг 4, после загрузки:
```
vxlan                 159744  0
ip6_udp_tunnel         16384  1 vxlan
udp_tunnel             36864  1 vxlan
```
После выгрузки вывода нет.

Решение:
```bash
modprobe dummy numdummies=3
modprobe -r dummy
modprobe vxlan
modprobe -r vxlan
```
Если `dummy` уже был загружен, сначала выгрузите его: повторный `modprobe` параметры
не меняет. Разбор — README, часть 2.
