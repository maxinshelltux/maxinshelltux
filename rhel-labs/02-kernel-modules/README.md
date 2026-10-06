# Лабораторная работа 02: модули ядра — загрузка, автозагрузка, параметры, запрет

## Оглавление
<!-- TOC -->
- [Соответствие целям экзамена RHCSA](#соответствие-целям-экзамена-rhcsa)
- [Предварительные требования](#предварительные-требования)
- [Стартовая проверка](#стартовая-проверка)
- [Часть 1: Что такое модуль и где его искать](#часть-1-что-такое-модуль-и-где-его-искать)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью)
  - [1.1 Что загружено сейчас](#11-что-загружено-сейчас)
  - [1.2 Где лежат файлы модулей](#12-где-лежат-файлы-модулей)
  - [1.3 Сведения о модуле и его зависимости](#13-сведения-о-модуле-и-его-зависимости)
- [Часть 2: Загрузка и выгрузка на работающей системе](#часть-2-загрузка-и-выгрузка-на-работающей-системе)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-1)
  - [2.1 Загрузить и выгрузить](#21-загрузить-и-выгрузить)
  - [2.2 Параметр модуля в командной строке](#22-параметр-модуля-в-командной-строке)
  - [2.3 Зависимости: modprobe против rmmod](#23-зависимости-modprobe-против-rmmod)
  - [2.4 Ошибки, которые надо узнавать](#24-ошибки-которые-надо-узнавать)
  - [2.5 Загруженное руками не переживает перезагрузку](#25-загруженное-руками-не-переживает-перезагрузку)
- [Часть 3: Автозагрузка и постоянные параметры](#часть-3-автозагрузка-и-постоянные-параметры)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-2)
  - [3.1 Автозагрузка через modules-load.d](#31-автозагрузка-через-modules-loadd)
  - [3.2 Параметр из файла и ловушка порядка](#32-параметр-из-файла-и-ловушка-порядка)
  - [3.3 Почему этот опыт шёл в /run, а не в /etc](#33-почему-этот-опыт-шёл-в-run-а-не-в-etc)
  - [3.4 Постоянный параметр: модуль brd](#34-постоянный-параметр-модуль-brd)
  - [3.5 Перезагрузиться и доказать](#35-перезагрузиться-и-доказать)
- [Часть 4: Запрет загрузки модуля](#часть-4-запрет-загрузки-модуля)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-3)
  - [4.1 Одна строка blacklist](#41-одна-строка-blacklist)
  - [4.2 blacklist и install /bin/false](#42-blacklist-и-install-binfalse)
  - [4.3 Перезагрузиться и доказать](#43-перезагрузиться-и-доказать)
  - [4.4 Нужно ли пересобирать initramfs](#44-нужно-ли-пересобирать-initramfs)
  - [4.5 Запрет параметром ядра](#45-запрет-параметром-ядра)
- [Часть 5: Troubleshooting](#часть-5-troubleshooting)
  - [Теория: диагностика по симптому](#теория-диагностика-по-симптому)
  - [Инцидент 1: параметр задан, а не действует](#инцидент-1-параметр-задан-а-не-действует)
  - [Инцидент 2: модуль в автозагрузке, а не загружается](#инцидент-2-модуль-в-автозагрузке-а-не-загружается)
- [Проверка модуля](#проверка-модуля)
- [Финальная карта ресурсов модуля](#финальная-карта-ресурсов-модуля)
- [Теоретические вопросы (итоговые)](#теоретические-вопросы-итоговые)
- [Практические задания (отработка)](#практические-задания-отработка)
- [Шпаргалка](#шпаргалка)
- [Чему вы научились](#чему-вы-научились)
- [Уборка](#уборка)
<!-- /TOC -->

> ⏱ время ~90 мин (с 3–4 перезагрузками) · сложность 2/5 · пререквизиты: модуль 01, root на RHEL 10

Цель: научиться управлять модулями ядра так, как это описано в официальной
документации RHEL 10. Четыре задачи: посмотреть, что загружено и что можно загрузить;
загрузить и выгрузить модуль на работающей системе; сделать так, чтобы модуль с
нужными параметрами загружался при каждом старте; запретить загрузку модуля. Каждую
постоянную настройку доводим до конца — перезагружаемся и доказываем.

> Все «ожидаемые выводы» сняты 2026-10-05 и 2026-10-06 на стенде `rhel10-lab`: RHEL
> 10.2, AWS `t3.small`, `kmod-31-13.el10`, `systemd-257-23.el10_2.2`, SELinux
> Enforcing. Ядро в первый день — `6.12.0-211.61.1.el10_2`, во второй —
> `6.12.0-211.62.1.el10_2`, поэтому в путях встречаются обе версии. У вас версии,
> размеры и MAC-адреса будут свои — важна **структура** вывода.

---

## Соответствие целям экзамена RHCSA

В списке целей экзамена EX200 для Red Hat Enterprise Linux 10 (сверен со
[страницей экзамена](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
2026-10-05) **отдельной цели про модули ядра нет**. Тема взята как продолжение
модуля 01: там мы передавали параметры ядру, здесь — его загружаемым частям.
Команды — из главы 3 «Managing kernel modules» официального руководства RHEL 10.

Цели EX200, которые модуль при этом отрабатывает (формулировки дословные):

| Что делаем в модуле | Цель EX200 (дословно) | Раздел целей |
|---|---|---|
| Запрет модуля параметром ядра через `grubby` (4.5) | Modify the system bootloader | Deploy, configure, and maintain systems |
| Перезагрузка, чтобы доказать постоянную настройку (2.5, 3.5, 4.3, 4.5) | Boot, reboot, and shut down a system normally | Operate running systems |
| Перезапуск и статус `systemd-modules-load.service` | Start and stop services and configure services to start automatically at boot | Deploy, configure, and maintain systems |
| Журнал службы автозагрузки, сообщения ядра, разбор медленной загрузки (3.3) | Locate and interpret system log files and journals | Operate running systems |
| Файлы в `/etc/modules-load.d` и `/etc/modprobe.d` | Create and edit text files | Understand and use essential tools |
| `man modprobe.d`, `man modules-load.d`, `modinfo` | Locate, read, and use system documentation including man, info, and files in /usr/share/doc | Understand and use essential tools |
| Фильтрация `lsmod` и `modprobe -c` | Use grep and regular expressions to analyze text | Understand and use essential tools |

Общее требование экзамена остаётся тем же: «configurations must persist after reboot
without intervention». Автозагрузка и запрет модуля считаются сделанными только после
проверки на перезагруженной системе.

---

## Предварительные требования

```bash
sudo -i                                   # всё в модуле делается под root
cd ~ec2-user/rhel-labs/02-kernel-modules  # sudo -i переносит в /root, вернитесь в каталог модуля
cat /etc/redhat-release; uname -r; rpm -q kmod
# Red Hat Enterprise Linux release 10.2 (Coughlan)
# 6.12.0-211.61.1.el10_2.x86_64
# kmod-31-13.el10.x86_64
```

Пути вида `./run.sh`, `./verify/…`, `./broken/…` даны от каталога модуля, а
`./scripts/qa/…` — от корня `rhel-labs`. После каждой перезагрузки вход начинается
заново: снова `sudo -i` и `cd` в каталог модуля.

Учебные модули выбраны так, чтобы ничего не сломать: `dummy` создаёт пустые сетевые
интерфейсы, `vxlan` без настройки не делает ничего, `brd` создаёт RAM-диски. Модули,
от которых зависит работа стенда (`xfs`, `nvme`, `ena`), мы только рассматриваем.

Одно ограничение стенда, о котором подробно в 3.3: **интерфейсы `dummy` нельзя
делать постоянными**. Если они появляются при старте, загрузка этой облачной машины
растягивается с 40 секунд до 5 минут.

---

## Стартовая проверка

```bash
command -v lsmod modinfo modprobe rmmod >/dev/null && echo "инструменты на месте"
# инструменты на месте

./run.sh | tail -n 2                      # сводка состояния, ничего не меняет
# === Что будет при следующей загрузке ===
# [OK] dummy в автозагрузке не указан — после перезагрузки загружен не будет
```

`./run.sh` целиком показывает, загружены ли учебные модули, какую конфигурацию
`modprobe` для них собрал из всех файлов и что произойдёт при следующей загрузке.

---

## Часть 1: Что такое модуль и где его искать

### Теория для изучения перед частью

- Модуль ядра — часть ядра в отдельном файле `*.ko.xz`. Его можно загрузить и
  выгрузить без перезагрузки. Модулями сделаны драйверы устройств, файловые системы,
  сетевые протоколы.
- Модули лежат в `/lib/modules/<версия ядра>/`. У каждого ядра свой набор: модуль от
  одного ядра в другое не загрузится.
- Зависимости между модулями записаны в `/lib/modules/<версия ядра>/modules.dep`.
- Источники: документация RHEL 10 «Managing, monitoring, and updating the kernel»,
  разделы 3.1–3.5; `man lsmod`, `man modinfo`.

### 1.1 Что загружено сейчас

```bash
lsmod | head -n 8
# Module                  Size  Used by
# cfg80211             1437696  0
# rfkill                 40960  2 cfg80211
# 8021q                  53248  0
# garp                   16384  1 8021q
# mrp                    20480  1 8021q
# stp                    12288  1 garp
# llc                    16384  2 stp,garp

lsmod | wc -l
# 45

head -n 3 /proc/modules
# cfg80211 1437696 0 - Live 0xffffffffc0c00000
# rfkill 40960 2 cfg80211, Live 0xffffffffc07fa000
# 8021q 53248 0 - Live 0xffffffffc07f4000
```

Три колонки `lsmod`: имя, размер в памяти и «кем занят» — счётчик и список модулей,
которые от него зависят. Ноль в счётчике значит, что модуль можно выгрузить. `lsmod`
лишь красиво печатает `/proc/modules`.

### 1.2 Где лежат файлы модулей

```bash
ls /lib/modules/
# 6.12.0-211.53.1.el10_2.x86_64
# 6.12.0-211.61.1.el10_2.x86_64

ls /lib/modules/$(uname -r)/kernel/
# arch
# crypto
# drivers
# fs
# kernel
# lib
# mm
# net
# samples
# sound
# virt

find /lib/modules/$(uname -r) -name '*.ko*' | wc -l
# 2255

modinfo -n dummy
# /lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz

rpm -qf $(modinfo -n dummy)
# kernel-modules-core-6.12.0-211.61.1.el10_2.x86_64
```

Загружено 44 модуля из 2255 доступных: ядро берёт только то, что нужно этой машине.
Два каталога в `/lib/modules/` — два установленных ядра из модуля 01. Файл модуля
принадлежит пакету `kernel-modules-core`; если нужного модуля нет, он может быть в
`kernel-modules` или `kernel-modules-extra`.

### 1.3 Сведения о модуле и его зависимости

```bash
modinfo dummy | grep -vE '^(sig|\s)'
# filename:       /lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz
# alias:          rtnl-link-dummy
# description:    Dummy netdevice driver which discards all packets sent to it
# license:        GPL
# rhelversion:    10.2
# srcversion:     A166064FFB707233D01CA12
# depends:        
# intree:         Y
# name:           dummy
# retpoline:      Y
# vermagic:       6.12.0-211.61.1.el10_2.x86_64 SMP preempt mod_unload modversions 
# parm:           numdummies:Number of dummy pseudo devices (int)

modinfo -p dummy
# numdummies:Number of dummy pseudo devices (int)

modinfo -F depends vxlan
# ip6_udp_tunnel,udp_tunnel

grep '/vxlan.ko.xz:' /lib/modules/$(uname -r)/modules.dep
# kernel/drivers/net/vxlan/vxlan.ko.xz: kernel/net/ipv6/ip6_udp_tunnel.ko.xz kernel/net/ipv4/udp_tunnel.ko.xz

modprobe --show-depends vxlan
# insmod /lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/net/ipv4/udp_tunnel.ko.xz 
# insmod /lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/net/ipv6/ip6_udp_tunnel.ko.xz 
# insmod /lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/drivers/net/vxlan/vxlan.ko.xz 
```

Что читать в `modinfo`:

| Поле | Что значит |
|---|---|
| `filename` | какой файл будет загружен |
| `depends` | модули, без которых этот не загрузится |
| `vermagic` | версия ядра, под которую модуль собран |
| `parm` | параметры, которые модуль принимает при загрузке |
| `signer` | кем подписан (в выводе выше строки подписи отфильтрованы) |

`modprobe --show-depends` ничего не загружает — только печатает, что и в каком
порядке `modprobe` выполнил бы. Это главный инструмент диагностики в частях 3–5.

**Контрольные вопросы**

1. Что показывает третья колонка `lsmod` и почему по ней видно, можно ли выгрузить
   модуль?
2. Почему в `/lib/modules/` на стенде два каталога?
3. Какой командой узнать, какие параметры принимает модуль, не загружая его?

---

## Часть 2: Загрузка и выгрузка на работающей системе

### Теория для изучения перед частью

- Официальные команды (документация RHEL 10, разделы 3.6 и 3.7):
  `modprobe <MODULE_NAME>` и `modprobe -r <MODULE_NAME>`; проверка — `lsmod`.
- `modprobe` сам загружает зависимости и читает настройки из `modprobe.d`. Команды
  `insmod` и `rmmod` работают с одним файлом и настроек не читают.
- Документация предупреждает: нельзя выгружать модули, которыми пользуется
  работающая система, — это может сделать её нерабочей.
- Загрузка модуля командой — действие на один сеанс: после перезагрузки его нет.

### 2.1 Загрузить и выгрузить

```bash
lsmod | grep dummy
# (пусто, код возврата 1)

modprobe dummy
# (вывода нет, код возврата 0)

lsmod | grep dummy
# dummy                  12288  0

ip -br link show type dummy
# (пусто: модуль загружен, но интерфейсов не создал — почему, разберём в 3.2)

modprobe -r dummy
lsmod | grep dummy
# (пусто, код возврата 1)
```

### 2.2 Параметр модуля в командной строке

```bash
modprobe dummy numdummies=2
ip -br link show type dummy
# dummy0           DOWN           4a:ab:76:33:86:87 <BROADCAST,NOARP> 
# dummy1           DOWN           a2:c1:c3:f7:54:b6 <BROADCAST,NOARP> 
```

Параметр действует только в момент загрузки. Повторный `modprobe` уже загруженного
модуля ничего не делает и об этом не сообщает:

```bash
modprobe dummy numdummies=3
# (вывода нет, код возврата 0)

ip -br link show type dummy | wc -l
# 2

modprobe -r dummy
ip -br link show type dummy
# (пусто)
```

Чтобы сменить параметр, модуль надо выгрузить и загрузить заново.

### 2.3 Зависимости: modprobe против rmmod

```bash
modprobe vxlan
lsmod | grep -E '^(vxlan|udp_tunnel|ip6_udp_tunnel) '
# vxlan                 159744  0
# ip6_udp_tunnel         16384  1 vxlan
# udp_tunnel             36864  1 vxlan

rmmod udp_tunnel
# rmmod: ERROR: Module udp_tunnel is in use by: vxlan

modprobe -r vxlan
lsmod | grep -E '^(vxlan|udp_tunnel|ip6_udp_tunnel) '
# (пусто: modprobe -r убрал модуль и ставшие ненужными зависимости)
```

`rmmod` убирает только названный модуль, зависимости остаются:

```bash
modprobe vxlan
rmmod vxlan
lsmod | grep -E '^(vxlan|udp_tunnel|ip6_udp_tunnel) '
# ip6_udp_tunnel         16384  0
# udp_tunnel             36864  0

modprobe -r ip6_udp_tunnel
modprobe -r udp_tunnel
```

### 2.4 Ошибки, которые надо узнавать

```bash
insmod /lib/modules/$(uname -r)/kernel/drivers/net/vxlan/vxlan.ko.xz
# insmod: ERROR: could not insert module /lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/drivers/net/vxlan/vxlan.ko.xz: Unknown symbol in module

dmesg | tail -n 3
# [ 1959.907471] vxlan: Unknown symbol udp_tun_rx_dst (err -2)
# [ 1959.908170] vxlan: Unknown symbol udp_tunnel_xmit_skb (err -2)
# [ 1959.908953] vxlan: Unknown symbol udp_tunnel_notify_del_rx_port (err -2)

modprobe no_such_module
# modprobe: FATAL: Module no_such_module not found in directory /lib/modules/6.12.0-211.61.1.el10_2.x86_64

modprobe -r xfs
# modprobe: FATAL: Module xfs is in use.
```

`insmod` не загрузил зависимости, и модулю не хватило функций из `udp_tunnel` —
причина всегда в `dmesg`. Модуль `xfs` занят корневой файловой системой, ядро его не
отдаёт.

### 2.5 Загруженное руками не переживает перезагрузку

```bash
modprobe vxlan
lsmod | grep -E '^(vxlan|udp_tunnel|ip6_udp_tunnel) '
# vxlan                 159744  0
# ip6_udp_tunnel         16384  1 vxlan
# udp_tunnel             36864  1 vxlan

systemctl reboot
```

После входа:

```bash
lsmod | grep -E '^(vxlan|udp_tunnel|ip6_udp_tunnel) '
# (пусто, код возврата 1)
```

Команда `modprobe` действует до перезагрузки. Чтобы модуль был загружен всегда,
нужна настройка из части 3.

**Контрольные вопросы**

1. Чем `modprobe -r vxlan` отличается от `rmmod vxlan` по результату?
2. Вы выполнили `modprobe dummy numdummies=3`, ошибок нет, а интерфейсов по-прежнему
   два. Почему?
3. Где искать причину, если `insmod` ответил «Unknown symbol in module»?

---

## Часть 3: Автозагрузка и постоянные параметры

### Теория для изучения перед частью

- Официальная команда (документация RHEL 10, раздел 3.9):
  `echo <MODULE_NAME> > /etc/modules-load.d/<MODULE_NAME>.conf`. Пересобирать
  initramfs для этого не нужно.
- Файлы `/etc/modules-load.d/*.conf` при старте читает служба
  `systemd-modules-load.service` (`man modules-load.d`): по одному имени модуля в
  строке, расширение обязательно `.conf`.
- Постоянные параметры задаются строкой `options <модуль> <параметр>=<значение>` в
  `/etc/modprobe.d/*.conf` (`man modprobe.d`). Там же сказано: все options
  складываются вместе.
- Те же файлы можно положить в `/run/modprobe.d/`. Каталог `/run` живёт в памяти, и
  такая настройка исчезает при перезагрузке — удобно для проб.
- Итог сложения всех файлов показывает `modprobe -c`, а то, что реально будет
  выполнено, — `modprobe --show-depends <модуль>`.

### 3.1 Автозагрузка через modules-load.d

```bash
echo dummy > /etc/modules-load.d/dummy.conf
cat /etc/modules-load.d/dummy.conf
# dummy

systemctl restart systemd-modules-load.service   # то же, что система делает при старте
lsmod | grep dummy
# dummy                  12288  0

journalctl -b -u systemd-modules-load.service --no-pager -o cat | tail -n 4
# Starting systemd-modules-load.service - Load Kernel Modules...
# Inserted module 'dummy'
# Module 'msr' is built in
# Finished systemd-modules-load.service - Load Kernel Modules.
```

Перезапуск службы позволяет проверить файл, не перезагружаясь. Окончательное
доказательство всё равно перезагрузка — она в 3.5.

### 3.2 Параметр из файла и ловушка порядка

Попробуем задать два интерфейса `dummy` через файл. Пробуем во временном каталоге
`/run/modprobe.d` — почему не в `/etc`, станет ясно в 3.3.

```bash
echo "options dummy numdummies=2" > /run/modprobe.d/lab-dummy.conf
modprobe -r dummy; modprobe dummy
ip -br link show type dummy
# (пусто: параметр не подействовал)
```

Спросим у `modprobe`, что он собрал из всех файлов:

```bash
modprobe -c | grep -E '^options dummy'
# options dummy numdummies=2
# options dummy numdummies=0

modprobe --show-depends dummy
# insmod /lib/modules/6.12.0-211.62.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz numdummies=2 numdummies=0 

grep -rn "dummy" /etc/modprobe.d/ /usr/lib/modprobe.d/ /run/modprobe.d/
# /usr/lib/modprobe.d/systemd.conf:18:# Do the same for dummy0.
# /usr/lib/modprobe.d/systemd.conf:20:options dummy numdummies=0
# /run/modprobe.d/lab-dummy.conf:1:options dummy numdummies=2
```

В системе уже есть строка `options dummy numdummies=0` — её ставит пакет `systemd` в
`/usr/lib/modprobe.d/systemd.conf`. Обе строки сложились, модуль получил
`numdummies=2 numdummies=0`, и подействовало последнее значение. Порядок задаёт имя
файла, а не каталог: `lab-dummy.conf` по алфавиту раньше, чем `systemd.conf`. Это же
объясняет пустой вывод в 2.1.

Назовём файл так, чтобы он шёл после `systemd.conf`:

```bash
mv /run/modprobe.d/lab-dummy.conf /run/modprobe.d/zz-lab-dummy.conf
modprobe -c | grep -E '^options dummy'
# options dummy numdummies=0
# options dummy numdummies=2

modprobe --show-depends dummy
# insmod /lib/modules/6.12.0-211.62.1.el10_2.x86_64/kernel/drivers/net/dummy.ko.xz numdummies=0 numdummies=2 

modprobe -r dummy; modprobe dummy
ip -br link show type dummy
# dummy0           DOWN           52:ca:cb:b5:70:63 <BROADCAST,NOARP> 
# dummy1           DOWN           72:2a:d0:37:7f:6d <BROADCAST,NOARP> 
```

Правило на всю жизнь: после правки `modprobe.d` смотрите не в свой файл, а в
`modprobe -c` и `modprobe --show-depends`.

Ещё одна особенность, пойманная на стенде: файл в `/etc/modprobe.d` перекрывает файл
с **тем же именем** в `/run/modprobe.d`. Когда в `/etc` лежал пустой
`zz-dummy.conf`, одноимённый файл в `/run` перестал учитываться вовсе.

### 3.3 Почему этот опыт шёл в /run, а не в /etc

При подготовке материалов тот же параметр сначала был записан постоянно — в
`/etc/modprobe.d/zz-dummy.conf`, вместе с автозагрузкой `dummy`. После перезагрузки
стенд не отвечал по SSH почти пять минут вместо обычных сорока секунд. Вот что
показала система, когда вход заработал:

```bash
systemd-analyze
# Startup finished in 1.099s (kernel) + 2.263s (initrd) + 4min 54.207s (userspace) = 4min 57.570s 
# multi-user.target reached after 4min 27.736s in userspace.

systemd-analyze blame | head -n 3
# 4min 23.348s cloud-init-local.service
#      26.614s kdump.service
#       3.284s dev-ttyS0.device

journalctl -b -u cloud-init-local.service --no-pager -o cat | grep -v url_helper | tail -n 6
# dummy0: IAID fb:7f:a5:58
# dummy0: soliciting a DHCP lease
# timed out
# dhcpcd exited
# 2026-10-06 08:05:57,707 - DataSourceEc2.py[WARNING]: IMDS's HTTP endpoint is probably disabled
# Finished cloud-init-local.service - Cloud-init: Local Stage (pre-network).
```

Как это читать. `systemd-analyze blame` называет виновника: служба
`cloud-init-local` работала 4 минуты 23 секунды. Её журнал объясняет почему:
интерфейс `dummy0` появился раньше настоящей сетевой карты, `cloud-init` попытался
получить через него адрес, не дождался и ещё четыре минуты искал службу метаданных
облака. Всё это время сеть не поднималась.

Строка `options dummy numdummies=0` в `systemd.conf` стоит именно ради этого: в самом
файле сказано, что интерфейс, появляющийся сам по себе, мешает управлению сетью.
Перебив её постоянной настройкой, мы получили ровно то, от чего она защищает.

Вывод для этого стенда: **не делайте `numdummies` больше нуля постоянным**. Файл в
`/run/modprobe.d` безопасен — при перезагрузке он исчезает. Для постоянного
параметра возьмём модуль, который не создаёт сетевых интерфейсов.

### 3.4 Постоянный параметр: модуль brd

`brd` создаёт диски в оперативной памяти. Параметр `rd_nr` — сколько дисков,
`rd_size` — размер каждого в килобайтах.

```bash
modinfo -F description brd; modinfo -p brd
# Ram backed block device driver
# rd_nr:Maximum number of brd devices (int)
# rd_size:Size of each RAM disk in kbytes. (ulong)
# max_part:Num Minors to reserve between devices (int)

echo brd > /etc/modules-load.d/brd.conf
echo "options brd rd_nr=2 rd_size=4096" > /etc/modprobe.d/brd.conf

modprobe -c | grep -E '^options brd'
# options brd rd_nr=2 rd_size=4096

modprobe --show-depends brd
# insmod /lib/modules/6.12.0-211.62.1.el10_2.x86_64/kernel/drivers/block/brd.ko.xz rd_nr=2 rd_size=4096 

systemctl restart systemd-modules-load.service
lsmod | grep -E '^(dummy|brd) '
# dummy                  12288  0
# brd                    16384  0

cat /sys/module/brd/parameters/rd_nr
# 2

lsblk /dev/ram0 /dev/ram1
# NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
# ram0   1:0    0   4M  0 disk 
# ram1   1:1    0   4M  0 disk 
```

У `brd` системных options нет, поэтому `modprobe -c` показывает одну строку и
ловушки порядка здесь нет. Параметры загруженного модуля видны в
`/sys/module/<модуль>/parameters/` — если модуль их туда выставляет; `dummy`,
например, свой `numdummies` не показывает.

### 3.5 Перезагрузиться и доказать

```bash
systemctl reboot
```

После входа:

```bash
lsmod | grep -E '^(dummy|brd) '
# dummy                  12288  0
# brd                    16384  0

cat /sys/module/brd/parameters/rd_nr
# 2

lsblk /dev/ram0 /dev/ram1
# NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
# ram0   1:0    0   4M  0 disk 
# ram1   1:1    0   4M  0 disk 

ip -br link show type dummy
# (пусто)

ls -l /run/modprobe.d/
# total 0

journalctl -b -t systemd-modules-load --no-pager -o cat
# Inserted module 'i2c_dev'
# Module 'msr' is built in
# Inserted module 'brd'
# Inserted module 'dummy'
# Module 'msr' is built in

systemd-analyze | head -n 1
# Startup finished in 1.266s (kernel) + 2.667s (initrd) + 33.029s (userspace) = 36.963s 
```

Оба модуля загрузились сами, `brd` — с нашим параметром. Интерфейсов `dummy` нет:
файл из `/run` исчез, и снова действует системный `numdummies=0`. Загрузка заняла 37
секунд.

Записи о загрузке модулей при старте ищите по имени программы (`-t
systemd-modules-load`): с ключом `-u systemd-modules-load.service` после
перезагрузки на стенде были видны только строки об остановке службы.

**Контрольные вопросы**

1. Какая служба читает `/etc/modules-load.d` и как проверить файл без перезагрузки?
2. Параметр записан в файле, но не действует. Какие две команды покажут причину?
3. Почему переименование файла в `zz-lab-dummy.conf` исправило дело?
4. Чем настройка в `/run/modprobe.d` отличается от настройки в `/etc/modprobe.d`?
5. Загрузка стала занимать пять минут. Какими командами найти виновника?

---

## Часть 4: Запрет загрузки модуля

### Теория для изучения перед частью

- Официальная процедура (документация RHEL 10, раздел 3.10): файл в
  `/etc/modprobe.d/` с двумя строками — `blacklist <модуль>` и
  `install <модуль> /bin/false`.
- `blacklist` по `man modprobe.d` означает одно: игнорировать внутренние псевдонимы
  модуля, то есть не загружать его автоматически по устройству. Загрузку по имени он
  не запрещает. Документация добавляет: `blacklist` не мешает загрузить модуль как
  зависимость другого.
- `install <модуль> /bin/false` заставляет `modprobe` вместо загрузки выполнить
  `/bin/false`, то есть завершиться отказом.
- Разовый запрет при старте (раздел 3.8) — параметр ядра
  `modprobe.blacklist=<модуль>`.

Исходное состояние для этой части — результат части 3: `dummy` и `brd` в
автозагрузке, интерфейсов `dummy` нет.

### 4.1 Одна строка blacklist

```bash
modprobe -r dummy
echo "blacklist dummy" > /etc/modprobe.d/lab-denylist.conf

modprobe dummy
lsmod | grep dummy
# dummy                  12288  0
```

Явная команда модуль загрузила: `blacklist` её не касается. А автозагрузка запрет
учитывает:

```bash
modprobe -r dummy
systemctl restart systemd-modules-load.service
lsmod | grep dummy
# (пусто, код возврата 1)

journalctl -b -u systemd-modules-load.service --no-pager -o cat | tail -n 3
# Module 'dummy' is deny-listed (by kmod)
# Module 'msr' is built in
# Finished systemd-modules-load.service - Load Kernel Modules.

systemctl is-active systemd-modules-load.service
# active
```

Служба при этом остаётся `active` и ошибкой пропуск не считает — запись есть только
в журнале. С ключом `-b` запрет учитывает и сам `modprobe`: `modprobe -b dummy`
молча ничего не загрузит.

### 4.2 blacklist и install /bin/false

```bash
printf 'blacklist dummy\ninstall dummy /bin/false\n' > /etc/modprobe.d/lab-denylist.conf
cat /etc/modprobe.d/lab-denylist.conf
# blacklist dummy
# install dummy /bin/false

modprobe dummy
# modprobe: ERROR: libkmod/libkmod-module.c:1084 command_do() Error running install command '/bin/false' for module dummy: retcode 1
# modprobe: ERROR: could not insert 'dummy': Invalid argument

lsmod | grep dummy
# (пусто, код возврата 1)

modprobe --show-depends dummy
# install /bin/false numdummies=0 
```

Теперь отказ получает и явная команда. `--show-depends` показывает подмену: вместо
`insmod` стоит `install /bin/false`.

Обойти оба запрета может только `insmod`: он не читает `modprobe.d`.

```bash
insmod /lib/modules/$(uname -r)/kernel/drivers/net/dummy.ko.xz
lsmod | grep dummy
# dummy                  12288  0
rmmod dummy
```

### 4.3 Перезагрузиться и доказать

```bash
systemctl reboot
```

После входа:

```bash
lsmod | grep dummy
# (пусто, код возврата 1)

journalctl -b -t systemd-modules-load --no-pager -o cat
# Inserted module 'i2c_dev'
# Module 'msr' is built in
# Inserted module 'brd'
# Module 'dummy' is deny-listed (by kmod)
# Module 'msr' is built in

systemctl is-active systemd-modules-load.service
# active

modprobe dummy
# modprobe: ERROR: libkmod/libkmod-module.c:1084 command_do() Error running install command '/bin/false' for module dummy: retcode 1
# modprobe: ERROR: could not insert 'dummy': Invalid argument
```

Запрет пережил перезагрузку: служба автозагрузки модуль пропустила, `brd` при этом
загрузился как обычно, а явная команда получает отказ.

Снимем запрет — очистим файл и дадим службе загрузить модуль:

```bash
: > /etc/modprobe.d/lab-denylist.conf
systemctl restart systemd-modules-load.service
lsmod | grep dummy
# dummy                  12288  0
```

### 4.4 Нужно ли пересобирать initramfs

Процедура из раздела 3.10 документации продолжается так: сделать копию initramfs,
пересобрать его командой `dracut -f -v` и перезагрузиться. Это нужно, когда
запрещаемый модуль входит в initramfs — тогда он загружается ещё до того, как
система прочитает `/etc/modprobe.d`. Проверить просто:

```bash
lsinitrd /boot/initramfs-$(uname -r).img | grep -c '\.ko'
# 508

lsinitrd /boot/initramfs-$(uname -r).img | grep -E 'dummy|xfs.ko'
# -rw-r--r--   1 root     root       937848 Jul 28 00:00 usr/lib/modules/6.12.0-211.61.1.el10_2.x86_64/kernel/fs/xfs/xfs.ko.xz
```

`dummy` в initramfs нет, значит, для него пересборка не нужна — запрет из
`/etc/modprobe.d` сработает и так. Для модуля, который там есть, команды по
документации такие:

```bash
cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).bak.$(date +%m-%d-%H%M%S).img
dracut -f -v
reboot
```

На стенде эти три команды **не выполнялись**: у него нет консоли, и ошибка в
initramfs оставила бы машину без возможности загрузиться и без способа это
исправить.

### 4.5 Запрет параметром ядра

Раздел 3.8 документации: в меню GRUB нажать `e`, дописать в конец строки `linux`
параметр `modprobe.blacklist=<модуль>` и загрузиться по Ctrl+X. Такая правка
действует одну загрузку. У стенда меню GRUB недоступно, поэтому тот же параметр
ставим инструментом из модуля 01 — и после проверки обязательно убираем.

```bash
grubby --update-kernel=DEFAULT --args="modprobe.blacklist=dummy"
grubby --info=DEFAULT | grep -E '^(index|kernel|args)='
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64"
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=never modprobe.blacklist=dummy"

systemctl reboot
```

(`transparent_hugepage=never` в этом выводе остался на стенде от занятия 01.)

После входа:

```bash
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M transparent_hugepage=never modprobe.blacklist=dummy

lsmod | grep dummy
# (пусто, код возврата 1)

journalctl -b -t systemd-modules-load --no-pager -o cat | grep dummy
# Module 'dummy' is deny-listed (by kmod)

modprobe -c | grep -E '^(blacklist|install|options) dummy'
# blacklist dummy
# options dummy numdummies=0

modprobe dummy; lsmod | grep dummy
# dummy                  12288  0
```

Параметр ядра работает как строка `blacklist`: `modprobe -c` показывает её, хотя ни
в одном файле её нет. Автозагрузка модуль пропустила, а явный `modprobe dummy` его
загрузил — как в 4.1. Убираем параметр:

```bash
modprobe -r dummy
grubby --update-kernel=DEFAULT --remove-args="modprobe.blacklist"
grubby --info=DEFAULT | grep -E '^(index|args)='
# index=1
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=never"
```

До следующей перезагрузки система всё ещё работает с этим параметром — `./run.sh`
об этом напомнит.

**Контрольные вопросы**

1. Что запрещает строка `blacklist dummy` и чего она не запрещает?
2. Зачем в документации к ней добавлена строка `install dummy /bin/false`?
3. Как узнать, нужно ли пересобирать initramfs после запрета модуля?
4. Чем запрет параметром `modprobe.blacklist=` в меню GRUB отличается от файла в
   `/etc/modprobe.d`?

---

## Часть 5: Troubleshooting

### Теория: диагностика по симптому

```text
Модуль ведёт себя не так, как настроено
├─ модуль не загружен после старта
│  ├─ его нет в /etc/modules-load.d/*.conf        → не прописан или не то расширение файла
│  ├─ journalctl -b -u systemd-modules-load:
│  │  ├─ «is deny-listed (by kmod)»               → где-то стоит blacklist (инцидент 2)
│  │  └─ «Failed to find module»                  → опечатка в имени
│  └─ /proc/cmdline содержит modprobe.blacklist=  → запрет параметром ядра
├─ modprobe завершается ошибкой
│  ├─ «Error running install command»             → строка install ... /bin/false
│  ├─ «not found in directory /lib/modules/...»   → нет такого модуля для этого ядра
│  └─ «is in use»                                 → модуль занят, смотри колонку Used by
└─ модуль загружен, но параметр не действует
   ├─ modprobe --show-depends: параметр не последний → перебит другим файлом (инцидент 1)
   └─ параметр меняли при загруженном модуле         → выгрузить и загрузить заново
```

Порядок проверки один: `lsmod` (что есть) → `modprobe -c | grep <модуль>` и
`modprobe --show-depends <модуль>` (что настроено) → журнал службы и `dmesg` (что
произошло). `./run.sh` собирает первые два шага.

### Инцидент 1: параметр задан, а не действует

Разбор и воспроизведение — в `broken/scenario-01/README.md`, исправление —
`solutions/01-options-order/fix.sh`.

### Инцидент 2: модуль в автозагрузке, а не загружается

Разбор и воспроизведение — в `broken/scenario-02/README.md`, исправление —
`solutions/02-denylisted-autoload/fix.sh`.

---

## Проверка модуля

```bash
sudo ./scripts/qa/run-module.sh 02-kernel-modules
# --- module: 02-kernel-modules ---
# prepare...
# [OK] стенд готов: ядро 6.12.0-211.62.1.el10_2.x86_64, модулей загружено 44, dummy загружен: нет, снимок /var/lib/rhel-labs/02-kernel-modules/baseline.txt
# verify...
# [OK] modprobe / modprobe -r: модуль dummy загружается и выгружается
# [OK] параметр в командной строке modprobe действует; повторная загрузка параметры не меняет
# [OK] параметры brd видны в /sys/module/brd/parameters: rd_nr=2, два RAM-диска
# [OK] ошибки: несуществующий модуль и выгрузка занятого модуля завершаются отказом
# [OK] зависимости: modprobe vxlan загружает и выгружает ip6_udp_tunnel udp_tunnel вместе с модулем
# [OK] автозагрузка: systemd-modules-load читает modules-load.d и загружает модуль
# [OK] параметры из modprobe.d: действует последнее значение, порядок задаёт имя файла
# [OK] blacklist: автозагрузка модуль пропускает, явный modprobe всё ещё загружает
# [OK] blacklist + install /bin/false: modprobe завершается отказом, модуль не загружен
# [OK] проверочные файлы обнулены, конфигурация dummy исходная
# [OK] module 02-kernel-modules verified
# [OK] модули лабы выгружены: dummy, brd, vxlan
# [DRY-RUN] был бы удалён: /etc/modules-load.d/dummy.conf (0 байт, пустой)
# [DRY-RUN] был бы удалён: /etc/modules-load.d/brd.conf (0 байт, пустой)
# [DRY-RUN] был бы удалён: /etc/modprobe.d/brd.conf (0 байт, пустой)
# [DRY-RUN] был бы удалён: /etc/modprobe.d/lab-denylist.conf (0 байт, пустой)
# [DRY-RUN] был бы удалён: /etc/modules-load.d/rhel-labs-qa.conf (0 байт, пустой)
# [DRY-RUN] был бы удалён: /etc/modprobe.d/zz-dummy.conf (0 байт, пустой)
# [WARN] файлов лабы на месте: 6; удаляет их только запуск с ключом: sudo ./verify/cleanup.sh --apply
# [OK] cleanup 02-kernel-modules (dry-run)
```

Строки `[DRY-RUN]` перечисляют файлы лабы в `/etc`. На стенде после подготовки
материалов они лежат пустыми и ни на что не влияют; на чистой машине останется одна
такая строка — про `rhel-labs-qa.conf`, файл самой проверки.

`run-module.sh` делает `prepare → verify → cleanup`. Проверка машину не
перезагружает. Она работает со своими файлами (`/etc/modules-load.d/rhel-labs-qa.conf`
и два файла в `/run/modprobe.d/`), а в конце оставляет их пустыми. Если в `/etc` или
`/run/modprobe.d` уже лежат ваши настройки из частей 3–4 или учебный модуль
загружен, `verify.sh` откажется работать и ничего не тронет — сначала уберите за
собой.

Проверку «после перезагрузки» скрипт сделать не может — её делаете вы, по шагам 3.5
и 4.3.

---

## Финальная карта ресурсов модуля

| Ресурс | Что это | Демонстрирует |
|---|---|---|
| `/proc/modules`, `lsmod` | загруженные модули | что работает сейчас |
| `/lib/modules/$(uname -r)/` | файлы модулей работающего ядра | что можно загрузить |
| `modules.dep` там же | карта зависимостей | почему `modprobe vxlan` тянет ещё два модуля |
| `/etc/modules-load.d/dummy.conf`, `brd.conf` | списки автозагрузки | модуль при каждом старте |
| `/run/modprobe.d/zz-lab-dummy.conf` | `options dummy numdummies=2`, до перезагрузки | порядок файлов и временную настройку |
| `/usr/lib/modprobe.d/systemd.conf` | системная строка `options dummy numdummies=0` | с чем складываются ваши options и зачем она нужна |
| `/etc/modprobe.d/brd.conf` | `options brd rd_nr=2 rd_size=4096` | постоянный параметр |
| `/sys/module/brd/parameters/` | параметры загруженного модуля | с чем модуль работает на самом деле |
| `/etc/modprobe.d/lab-denylist.conf` | `blacklist` и `install /bin/false` | запрет загрузки |
| `modprobe -c`, `modprobe --show-depends` | итог сложения всех файлов | что `modprobe` сделает на самом деле |
| `systemd-modules-load.service` | служба автозагрузки | кто читает `modules-load.d` и что пишет в журнал |
| `/var/lib/rhel-labs/02-kernel-modules/baseline.txt` | снимок до начала работы | с чем сравнивать |

---

## Теоретические вопросы (итоговые)

1. Чем загруженный модуль отличается от установленного и какими командами смотреть
   то и другое?
2. Почему для загрузки предпочитают `modprobe`, а не `insmod`?
3. Где задаётся автозагрузка модуля, а где его постоянные параметры?
4. Два файла в `modprobe.d` задают один параметр по-разному. Какое значение
   подействует и как это проверить, не загружая модуль?
5. Чем `blacklist` отличается от `install <модуль> /bin/false`?
6. В каком случае запрет модуля требует пересборки initramfs?

> Разбор ответов — в `ANSWERS.md`.

---

## Практические задания (отработка)

См. `tasks/`. В списке целей EX200 отдельной цели про модули ядра нет; в каждом
задании названы цели, на которые оно опирается.

1. **`tasks/01-load-unload.md`** — изучить модуль, загрузить с параметром, выгрузить
   вместе с зависимостями.
2. **`tasks/02-autoload-and-options.md`** — модуль `brd` с параметром при каждой
   загрузке, доказательство после перезагрузки.
3. **`tasks/03-denylist.md`** — запретить загрузку модуля, доказать после
   перезагрузки, вернуть как было.

---

## Шпаргалка

```bash
# === Посмотреть ===
lsmod | grep <модуль>                           # загружен ли и кем занят
modinfo <модуль>; modinfo -p <модуль>           # файл, зависимости, параметры
modprobe --show-depends <модуль>                # что выполнит modprobe
modprobe -c | grep -E '^(options|blacklist|install) <модуль>'   # итог всех файлов

# === На работающей системе ===
modprobe <модуль> [параметр=значение]           # загрузить с зависимостями
modprobe -r <модуль>                            # выгрузить с ненужными зависимостями

# === Постоянно ===
echo <модуль> > /etc/modules-load.d/<модуль>.conf                     # автозагрузка
echo "options <модуль> <параметр>=<значение>" > /etc/modprobe.d/<имя>.conf
systemctl restart systemd-modules-load.service                         # проверить без перезагрузки
cat /sys/module/<модуль>/parameters/<параметр>                         # с чем модуль загружен
# то же в /run/modprobe.d/ — только до перезагрузки, для проб

# === Запретить ===
printf 'blacklist <модуль>\ninstall <модуль> /bin/false\n' > /etc/modprobe.d/denylist.conf
lsinitrd /boot/initramfs-$(uname -r).img | grep <модуль>    # есть в initramfs — нужен dracut -f -v

# === Применить и доказать ===
systemctl reboot
lsmod | grep <модуль>; journalctl -b -t systemd-modules-load
systemd-analyze; systemd-analyze blame | head     # если загрузка стала долгой
```

---

## Чему вы научились

- Отличать загруженные модули от доступных и читать `modinfo`.
- Загружать и выгружать модули с зависимостями и параметрами.
- Настраивать автозагрузку и постоянные параметры и проверять итог через
  `modprobe -c`, а не по своему файлу.
- Пробовать настройку в `/run/modprobe.d`, прежде чем делать её постоянной, и
  находить причину медленной загрузки через `systemd-analyze blame`.
- Запрещать модуль и понимать разницу между `blacklist` и `install /bin/false`.
- Находить причину в журнале службы автозагрузки и в `dmesg`.

---

## Уборка

```bash
sudo ./verify/cleanup.sh
```

Без ключа скрипт выгружает учебные модули, убирает параметр
`modprobe.blacklist=dummy` из записей загрузчика, обнуляет временные файлы лабы в
`/run/modprobe.d` и **показывает**, какие файлы лабы лежат в `/etc`, — сами эти
файлы он не трогает:

```text
[OK] модули лабы выгружены: dummy, brd, vxlan
[DRY-RUN] был бы удалён: /etc/modules-load.d/dummy.conf (6 байт, строк: 1)
[DRY-RUN] был бы удалён: /etc/modules-load.d/brd.conf (0 байт, пустой)
[DRY-RUN] был бы удалён: /etc/modprobe.d/brd.conf (0 байт, пустой)
[DRY-RUN] был бы удалён: /etc/modprobe.d/lab-denylist.conf (0 байт, пустой)
[DRY-RUN] был бы удалён: /etc/modules-load.d/rhel-labs-qa.conf (0 байт, пустой)
[DRY-RUN] был бы удалён: /etc/modprobe.d/zz-dummy.conf (0 байт, пустой)
[WARN] файлов лабы на месте: 6; удаляет их только запуск с ключом: sudo ./verify/cleanup.sh --apply
[OK] временный файл обнулён: /run/modprobe.d/lab-dummy.conf
[OK] временный файл обнулён: /run/modprobe.d/zz-lab-dummy.conf
[OK] cleanup 02-kernel-modules (dry-run)
```

Пока файлы в `/etc/modules-load.d` не удалены, `dummy` и `brd` будут загружаться при
каждом старте. Это безвредно, но стенд после такой уборки не чистый.

Удаляет файлы только запуск с ключом, и запускает его человек:

```bash
sudo ./verify/cleanup.sh --apply
```

С `--apply` скрипт удаляет ровно семь путей: `/etc/modules-load.d/dummy.conf`,
`/etc/modules-load.d/brd.conf`, `/etc/modprobe.d/brd.conf`,
`/etc/modprobe.d/lab-denylist.conf`, `/etc/modules-load.d/rhel-labs-qa.conf` и два
имени из первой версии лабы — `/etc/modprobe.d/dummy.conf` и
`/etc/modprobe.d/zz-dummy.conf`. Если в файле есть строки не из лабы, он
останавливается и файл не трогает. Этот режим при подготовке материалов не
запускался. После уборки перезагрузитесь, если система была загружена с
`modprobe.blacklist=`.
