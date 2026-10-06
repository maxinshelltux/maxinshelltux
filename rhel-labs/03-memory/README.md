# Лабораторная работа 03: память — адресное пространство, выделение, нехватка, swap

## Оглавление
<!-- TOC -->
- [Соответствие целям экзамена RHCSA](#соответствие-целям-экзамена-rhcsa)
- [Предварительные требования](#предварительные-требования)
- [Стартовая проверка](#стартовая-проверка)
- [Часть 1: Сколько памяти и чем она занята](#часть-1-сколько-памяти-и-чем-она-занята)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью)
  - [1.1 Общая картина: free и /proc/meminfo](#11-общая-картина-free-и-procmeminfo)
  - [1.2 Страничный кеш: занято не значит потеряно](#12-страничный-кеш-занято-не-значит-потеряно)
- [Часть 2: Адресное пространство процесса](#часть-2-адресное-пространство-процесса)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-1)
  - [2.1 Размер страницы и ширина адреса](#21-размер-страницы-и-ширина-адреса)
  - [2.2 Карта памяти процесса](#22-карта-памяти-процесса)
  - [2.3 VSZ и RSS живого процесса](#23-vsz-и-rss-живого-процесса)
- [Часть 3: Выделение памяти: запрос не равен выдаче](#часть-3-выделение-памяти-запрос-не-равен-выдаче)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-2)
  - [3.1 Запросить и не трогать](#31-запросить-и-не-трогать)
  - [3.2 Записать в страницы](#32-записать-в-страницы)
  - [3.3 Сколько ядро готово пообещать](#33-сколько-ядро-готово-пообещать)
- [Часть 4: Найти и остановить прожорливый процесс](#часть-4-найти-и-остановить-прожорливый-процесс)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-3)
  - [4.1 Найти](#41-найти)
  - [4.2 Завершить](#42-завершить)
  - [4.3 SIGKILL и его след](#43-sigkill-и-его-след)
- [Часть 5: Когда памяти не хватает](#часть-5-когда-памяти-не-хватает)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-4)
  - [5.1 Предел памяти для одного процесса](#51-предел-памяти-для-одного-процесса)
  - [5.2 Что осталось в журнале](#52-что-осталось-в-журнале)
- [Часть 6: Swap](#часть-6-swap)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-5)
  - [6.1 Раздел на пустом диске](#61-раздел-на-пустом-диске)
  - [6.2 Область подкачки и её включение](#62-область-подкачки-и-её-включение)
  - [6.3 Сделать постоянным](#63-сделать-постоянным)
  - [6.4 Перезагрузиться и доказать](#64-перезагрузиться-и-доказать)
  - [6.5 Подкачка в деле](#65-подкачка-в-деле)
- [Часть 7: Troubleshooting](#часть-7-troubleshooting)
  - [Теория: диагностика по симптому](#теория-диагностика-по-симптому)
  - [Инцидент 1: процесс убили, а он вернулся](#инцидент-1-процесс-убили-а-он-вернулся)
  - [Инцидент 2: swap пропал после перезагрузки](#инцидент-2-swap-пропал-после-перезагрузки)
- [Проверка модуля](#проверка-модуля)
- [Финальная карта ресурсов модуля](#финальная-карта-ресурсов-модуля)
- [Теоретические вопросы (итоговые)](#теоретические-вопросы-итоговые)
- [Практические задания (отработка)](#практические-задания-отработка)
- [Шпаргалка](#шпаргалка)
- [Чему вы научились](#чему-вы-научились)
- [Уборка](#уборка)
<!-- /TOC -->

> ⏱ время ~110 мин (с 1–2 перезагрузками) · сложность 3/5 · пререквизиты: модули 01–02, root на RHEL 10

Цель: понимать, что на самом деле показывают `free`, `ps` и `top`, и уметь делать с
памятью то, что требует экзамен RHCSA: найти процесс, который её съел, и остановить
его; добавить системе swap так, чтобы он пережил перезагрузку; прочитать в журнале,
почему процесс был убит. Первые три части — фон: без него числа из `free` читаются
неправильно. Части 4–6 — экзаменационная практика.

> Все «ожидаемые выводы» сняты 2026-10-05 и 2026-10-06 на стенде `rhel10-lab`: RHEL
> 10.2, AWS `t3.small` (2 vCPU, 1647 МиБ памяти, swap изначально нет),
> `procps-ng-4.0.4-11.el10`, Python 3.12.14, cgroup v2. Ядро в первый день —
> `6.12.0-211.61.1.el10_2`, во второй — `6.12.0-211.62.1.el10_2`. У вас PID, адреса
> и точные числа будут свои — важны **соотношения**.

---

## Соответствие целям экзамена RHCSA

Формулировки целей приведены дословно со
[страницы экзамена EX200](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
(версия для Red Hat Enterprise Linux 10, сверено 2026-10-05).

| Что делаем в модуле | Цель EX200 (дословно) | Раздел целей |
|---|---|---|
| Найти процесс, который ест память, и завершить его (часть 4, задание 01) | Identify CPU/memory intensive processes and kill processes | Operate running systems |
| Добавить системе swap на новом разделе, не трогая существующее (часть 6, задание 02) | Add new partitions and logical volumes, and swap to a system non-destructively | Configure local storage |
| Таблица разделов GPT и раздел на пустом диске (6.1) | List, create, and delete partitions on GPT disks | Configure local storage |
| Строка swap в `/etc/fstab` по UUID (6.3) | Configure systems to mount file systems at boot by universally unique ID (UUID) or label | Configure local storage |
| Найти в журнале ядра, почему процесс убит (часть 5, задание 03) | Locate and interpret system log files and journals | Operate running systems |
| Остановить процесс, который запущен как служба (4.2, инцидент 1) | Start and stop services and configure services to start automatically at boot | Deploy, configure, and maintain systems |
| Перезагрузка, чтобы доказать постоянный swap (6.4) | Boot, reboot, and shut down a system normally | Operate running systems |

Адресное пространство, разница между запросом и выдачей памяти, overcommit и
пределы cgroup (части 1–3 и 5.1) отдельными целями EX200 **не являются**. Это фон
для целей из таблицы.

Общее требование экзамена: «configurations must persist after reboot without
intervention». Swap считается добавленным только после проверки на перезагруженной
системе.

---

## Предварительные требования

```bash
sudo -i                                   # всё в модуле делается под root
cd ~ec2-user/rhel-labs/03-memory          # sudo -i переносит в /root, вернитесь в каталог модуля
python3 --version; free -m
# Python 3.12.14
#                total        used        free      shared  buff/cache   available
# Mem:            1647         393        1082           6         312        1253
# Swap:              0           0           0
```

Пути вида `./run.sh`, `./memhog.py`, `./verify/…` даны от каталога модуля, а
`./scripts/qa/…` — от корня `rhel-labs`.

`memhog.py` — учебная программа: запрашивает у ядра заданное число мебибайт и
печатает, что при этом изменилось. Все её числа — в МиБ.

```bash
./memhog.py --help
# usage: memhog.py [-h] [--touch] [--hold SEC] mib
#
# Запрашивает у ядра анонимную память и показывает в МиБ, что при этом меняется.
#
# positional arguments:
#   mib         сколько мебибайт запросить
#
# options:
#   -h, --help  show this help message and exit
#   --touch     записать по байту в каждую страницу
#   --hold SEC  держать память столько секунд
```

Опыты с нехваткой памяти идут внутри ограниченной группы процессов (`systemd-run -p
MemoryMax=…`), так что стенду и вашей сессии они не угрожают. Доводить до нехватки
памяти всю систему в модуле не нужно и нельзя.

---

## Стартовая проверка

```bash
command -v free vmstat ps top pmap >/dev/null && echo "инструменты на месте"
# инструменты на месте

./run.sh | tail -n 2                      # сводка состояния, ничего не меняет
# === Что будет после перезагрузки ===
# [OK] swap не настроен — после перезагрузки его не будет
```

`./run.sh` целиком показывает память системы, пять самых крупных процессов,
состояние учебного процесса и swap.

---

## Часть 1: Сколько памяти и чем она занята

### Теория для изучения перед частью

- Ядро не держит память пустой: свободные страницы оно отдаёт под кеш файлов
  (страничный кеш) и забирает обратно, как только память понадобится процессам.
- Поэтому в `free` важна колонка `available` — оценка того, сколько памяти можно
  отдать новым процессам без подкачки, а не колонка `free`.
- `free` и `vmstat` берут числа из `/proc/meminfo`.
- Источники: `man free`, `man vmstat`. Страницы `man proc` на стенде нет
  (`No manual entry for proc`).

### 1.1 Общая картина: free и /proc/meminfo

```bash
free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         393        1082           6         312        1253
# Swap:              0           0           0

grep -E '^(MemTotal|MemFree|MemAvailable|Cached|AnonPages|SwapTotal|CommitLimit|Committed_AS):' /proc/meminfo
# MemTotal:        1686832 kB
# MemFree:         1108860 kB
# MemAvailable:    1283644 kB
# Cached:           300716 kB
# SwapTotal:             0 kB
# AnonPages:         77680 kB
# CommitLimit:      843416 kB
# Committed_AS:     236720 kB

vmstat 1 3
# procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
#  0  0      0 1108404   2232 318172    0    0   159     4  190    1  1  1 98  0  0  0
#  0  0      0 1108372   2232 318204    0    0     0     0  114  107  0  0 100  0  0  0
#  0  0      0 1108372   2232 318204    0    0     0     0  101  110  0  0 100  0  0  0
```

| Что | Где смотреть | Смысл |
|---|---|---|
| всего памяти | `total`, `MemTotal` | то, что ядро получило от машины |
| никем не занято | `free`, `MemFree` | пустые страницы |
| кеш файлов | `buff/cache`, `Cached` | занято, но отдаётся по первому требованию |
| можно отдать процессам | `available`, `MemAvailable` | главное число для ответа «хватит ли памяти» |
| данные процессов | `AnonPages` | память без файла за спиной: куча, стек |
| подкачка | `Swap`, колонки `si`/`so` в `vmstat` | страницы, вытесненные на диск, и их движение |

`CommitLimit` и `Committed_AS` понадобятся в части 3.

### 1.2 Страничный кеш: занято не значит потеряно

Сбросим кеш, прочитаем полгигабайта файлов и посмотрим, куда делась память:

```bash
sync; echo 3 > /proc/sys/vm/drop_caches
free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         302        1391           7          59        1345
# Swap:              0           0           0

find /usr/lib/modules /usr/lib64 -xdev -type f -exec cat {} + > /dev/null
free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         356         863           7         573        1290
# Swap:              0           0           0
```

`free` упал с 1391 до 863 МиБ, `buff/cache` вырос с 59 до 573, а `available` почти
не изменился: 1345 → 1290. Память, занятая кешем, по-прежнему доступна. Докажем —
попросим 900 МиБ, больше, чем показывает `free`:

```bash
./memhog.py 900 --touch
# pid 6120, запрос 900 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1288  Committed_AS=  243
# после mmap     VmSize=  914  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1288  Committed_AS= 1143
# после записи   VmSize=  914  VmRSS=  910  VmSwap=    0  |  MemAvailable=  392  Committed_AS= 1143

free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         376         948           7         469        1271
# Swap:              0           0           0
```

Процесс получил свои 910 МиБ, хотя «свободных» было 863: ядро отдало ему часть кеша
(`buff/cache` уменьшился с 573 до 469). Сброс кеша командой `echo 3 >
/proc/sys/vm/drop_caches` — приём для опыта, а не способ «освободить память» на
рабочем сервере.

**Контрольные вопросы**

1. По какой колонке `free` отвечать на вопрос «хватит ли памяти новому процессу» и
   почему не по колонке `free`?
2. После чтения файлов `buff/cache` вырос на полгигабайта. Стало ли памяти меньше?
3. Откуда `free` и `vmstat` берут свои числа?

---

## Часть 2: Адресное пространство процесса

### Теория для изучения перед частью

- У каждого процесса своё виртуальное адресное пространство — диапазон адресов, в
  котором он «видит» память. Адреса виртуальные: два процесса могут использовать один
  и тот же адрес, и это будут разные данные.
- Пространство поделено на области: код программы, её данные, куча, отображённые
  библиотеки и файлы, стек. Каждая область видна в `/proc/<PID>/maps`.
- Ядро отображает виртуальные адреса на физическую память страницами. Страница может
  быть обещана процессу, но ещё не выдана.
- Отсюда два разных размера: **VSZ** (VmSize) — сколько адресов обещано, **RSS**
  (VmRSS) — сколько страниц реально лежит в памяти.
- Источники: `man ps`, `man pmap`, `man top`.

### 2.1 Размер страницы и ширина адреса

```bash
getconf PAGE_SIZE
# 4096

lscpu | grep 'Address sizes'
# Address sizes:                           46 bits physical, 48 bits virtual
```

Страница — 4096 байт. Виртуальный адрес — 48 бит, то есть процессу теоретически
доступно 256 ТиБ адресов при 1647 МиБ настоящей памяти. Виртуальных адресов всегда
несравнимо больше, чем памяти.

### 2.2 Карта памяти процесса

`cat /proc/self/maps` показывает карту самого `cat` (вывод сокращён до одной строки
на область):

```bash
cat /proc/self/maps
# 55cbbc972000-55cbbc974000 r--p 00000000 103:05 16908733                  /usr/bin/cat
# 55cbbc974000-55cbbc979000 r-xp 00002000 103:05 16908733                  /usr/bin/cat
# 55cbbc97c000-55cbbc97d000 rw-p 00009000 103:05 16908733                  /usr/bin/cat
# 55cbd64fd000-55cbd651e000 rw-p 00000000 00:00 0                          [heap]
# 7f606f2a0000-7f606f2c8000 r--p 00000000 103:05 165                       /usr/lib64/libc.so.6
# 7f606f2c8000-7f606f418000 r-xp 00028000 103:05 165                       /usr/lib64/libc.so.6
# 7f606f485000-7f606f487000 r-xp 00000000 00:00 0                          [vdso]
# 7ffe55c55000-7ffe55c76000 rw-p 00000000 00:00 0                          [stack]
# ffffffffff600000-ffffffffff601000 --xp 00000000 00:00 0                  [vsyscall]
```

| Колонка | Пример | Смысл |
|---|---|---|
| диапазон адресов | `55cbd64fd000-55cbd651e000` | начало и конец области |
| права | `rw-p` | чтение, запись, исполнение; `p` — частная копия |
| файл | `/usr/lib64/libc.so.6` | что отображено; пусто или `[heap]` — память без файла |

Код (`r-xp`) нельзя менять, данные (`rw-p`) нельзя исполнять. Куча растёт вверх от
программы, стек лежит у верхней границы, библиотеки — между ними.

### 2.3 VSZ и RSS живого процесса

Запустим процесс, который займёт 200 МиБ и подержит их две минуты:

```bash
./memhog.py 200 --touch --hold 120 > /dev/null &
PID=$!

ps -o pid,vsz,rss,pmem,args -p $PID
#     PID    VSZ   RSS %MEM COMMAND
#   12616 220012 216016 12.8 python3 ./memhog.py 200 --touch --hold 120

grep -E '^(VmSize|VmRSS|RssAnon|RssFile|VmData|VmStk|VmExe|VmLib|VmSwap):' /proc/$PID/status
# VmSize:	  220012 kB
# VmRSS:	  216016 kB
# RssAnon:	  209928 kB
# RssFile:	    6088 kB
# VmData:	  211320 kB
# VmStk:	     132 kB
# VmExe:	       4 kB
# VmLib:	    4700 kB
# VmSwap:	       0 kB

pmap -x $PID | sort -k2 -n -r | head -n 4
# 00007fa2b5200000  204800  204800  204800 rw---   [ anon ]
# 00007fa2c1d10000    2440    1976    1976 rw---   [ anon ]
# 00007fa2c227d000    2436    2052       0 r-x-- libpython3.12.so.1.0
# 00007fa2c26b1000    1464    1220    1212 rw--- libpython3.12.so.1.0

pmap -x $PID | tail -n 1
# total kB          220016  216016  209928

kill $PID
```

`VSZ` в `ps` — это `VmSize`, `RSS` — `VmRSS`, оба в килобайтах. Самая большая область
в `pmap` — те самые 204800 КиБ (200 МиБ), которые программа запросила: область без
имени файла, `[ anon ]`. `RssAnon` — память самого процесса, `RssFile` — страницы
библиотек, которые он делит с другими.

**Контрольные вопросы**

1. Чем VSZ отличается от RSS и какое из двух чисел говорит о расходе памяти?
2. Что означает область без имени файла в `/proc/<PID>/maps`?
3. Почему виртуальных адресов у процесса может быть больше, чем памяти в машине?

---

## Часть 3: Выделение памяти: запрос не равен выдаче

### Теория для изучения перед частью

- Когда программа просит память, ядро только резервирует адреса. Физическую страницу
  оно выдаёт при первом обращении к ней.
- Поэтому сумма обещанного всем процессам (`Committed_AS`) может превышать и
  настоящую память, и предел `CommitLimit`. Это называется overcommit.
- Режим задаёт `vm.overcommit_memory`. Документация ядра («Overcommit Accounting»):
  `0` — эвристика, отклоняются только очевидно завышенные запросы; `1` — обещать
  всегда; `2` — не обещать больше, чем swap плюс доля памяти (по умолчанию 50%).
  Там же сказано, что текущий предел и объём обещанного видны в `/proc/meminfo` как
  `CommitLimit` и `Committed_AS`.
- На стенде режим `0`. Режимы `1` и `2` здесь **не включались**: строгий режим на
  машине с 1,6 ГиБ памяти может не дать запуститься новым процессам, включая вашу
  SSH-сессию.

### 3.1 Запросить и не трогать

```bash
./memhog.py 300
# pid 5556, запрос 300 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1266  Committed_AS=  234
# после mmap     VmSize=  314  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1266  Committed_AS=  534
```

Процесс получил 300 МиБ адресов: `VmSize` вырос с 14 до 314. Памяти при этом не
потрачено ни мегабайта — `VmRSS` и `MemAvailable` не изменились. Выросло только
`Committed_AS`, счётчик обещанного.

### 3.2 Записать в страницы

```bash
./memhog.py 300 --touch
# pid 5557, запрос 300 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1266  Committed_AS=  234
# после mmap     VmSize=  314  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1266  Committed_AS=  534
# после записи   VmSize=  314  VmRSS=  310  VmSwap=    0  |  MemAvailable=  966  Committed_AS=  534
```

Только запись в каждую страницу заставила ядро выдать память: `VmRSS` стал 310, а
`MemAvailable` уменьшился на те же 300 МиБ.

### 3.3 Сколько ядро готово пообещать

```bash
sysctl vm.overcommit_memory vm.overcommit_ratio
# vm.overcommit_memory = 0
# vm.overcommit_ratio = 50

grep -E '^(MemTotal|CommitLimit|Committed_AS):' /proc/meminfo
# MemTotal:        1686832 kB
# CommitLimit:      843416 kB
# Committed_AS:     233388 kB

./memhog.py 1600
# pid 5562, запрос 1600 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1230  Committed_AS=  234
# после mmap     VmSize= 1614  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1230  Committed_AS= 1834

./memhog.py 1700
# pid 5563, запрос 1700 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1230  Committed_AS=  234
# mmap 1700 МиБ: отказ ядра — Cannot allocate memory
```

1600 МиБ ядро пообещало, хотя доступно было 1230, а `CommitLimit` — всего 823 МиБ. А
1700 МиБ — больше всей памяти машины (1647 МиБ) — отклонило сразу: это и есть
«очевидно завышенный запрос». В режиме `0` значение `CommitLimit` — справка, а не
ограничение.

Три процесса по 1200 МиБ одновременно:

```bash
for i in 1 2 3; do ./memhog.py 1200 --hold 6 > /dev/null & done; sleep 2
grep -E '^(MemAvailable|CommitLimit|Committed_AS):' /proc/meminfo
# MemAvailable:    1253308 kB
# CommitLimit:      843416 kB
# Committed_AS:    3941332 kB

ps -eo pid,vsz,rss,pmem,args --sort=-vsz | head -n 4
#     PID    VSZ   RSS %MEM COMMAND
#    5565 1244012 11056  0.6 python3 ./memhog.py 1200 --hold 6
#    5566 1244012 11036  0.6 python3 ./memhog.py 1200 --hold 6
#    5567 1244012 11032  0.6 python3 ./memhog.py 1200 --hold 6
wait
```

Обещано 3,9 ГиБ при 1,6 ГиБ памяти, и ничего не случилось: каждый процесс занимает
11 МиБ. Проблемы начнутся, только если все трое начнут в свою память писать — об
этом часть 5.

**Контрольные вопросы**

1. Какое число в выводе `memhog.py` меняется при запросе памяти, а какое — только
   при записи?
2. Почему `VSZ` процесса — плохой показатель расхода памяти?
3. Запрос на 1600 МиБ прошёл, на 1700 — нет. Что ядро сравнивало?

---

## Часть 4: Найти и остановить прожорливый процесс

### Теория для изучения перед частью

- Цель экзамена: *Identify CPU/memory intensive processes and kill processes*.
- Найти: `ps` с сортировкой по RSS или `top`, отсортированный по `%MEM`.
- Завершить: `kill <PID>` посылает SIGTERM — просьбу завершиться. `kill -9` (SIGKILL)
  ядро исполняет само, процесс не может его перехватить. Начинают с SIGTERM.
- По имени: `pgrep` находит, `pkill` посылает сигнал.
- Источники: `man ps`, `man top`, `man kill`, `man pkill`.

Запустим «виновника» как фоновую службу с пределом памяти на всякий случай:

```bash
systemd-run --unit=lab-memhog -p MemoryMax=500M /usr/bin/python3 "$PWD/memhog.py" 300 --touch --hold 900
# Running as unit: lab-memhog.service; invocation ID: ef35002ecb4e415b9882272f6512813f
```

Здесь явно указан `/usr/bin/python3`: запустить скрипт из домашнего каталога напрямую
служба не может — SELinux не разрешает `systemd` исполнять файлы с меткой
`user_home_t` (служба завершится со `status=203/EXEC`).

### 4.1 Найти

```bash
free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         665         807           7         318         981
# Swap:              0           0           0

ps aux --sort=-rss | head -n 4
# USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
# root        6006  2.6 18.8 322420 318652 ?       Ss   13:53   0:00 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
# root           1  0.1  2.1  44404 36156 ?        Ss   13:16   0:02 /usr/lib/systemd/systemd --switched-root --system --deserialize=50
# root         793  0.0  1.6 256632 27616 ?        Ssl  13:16   0:00 /usr/bin/python3 -Es /usr/sbin/tuned -l -P

ps -eo pid,user,rss,vsz,pmem,args --sort=-rss | head -n 4
#     PID USER       RSS    VSZ %MEM COMMAND
#    6006 root     318652 322420 18.8 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
#       1 root     36156  44404  2.1 /usr/lib/systemd/systemd --switched-root --system --deserialize=50
#     793 root     27616 256632  1.6 /usr/bin/python3 -Es /usr/sbin/tuned -l -P

top -b -n 1 -o %MEM | sed -n '7,10p'
#     PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
#    6006 root      20   0  322420 318652   6296 S   0.0  18.9   0:00.08 python3
#       1 root      20   0   44404  36156  10372 S   0.0   2.1   0:02.47 systemd
#     793 root      20   0  256632  27616  12916 S   0.0   1.6   0:00.56 tuned

pgrep -af memhog
# 6006 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
```

`available` упал с 1265 до 981 МиБ. Первая строка в любом из трёх списков —
виновник: PID 6006, 318652 КиБ RSS, 18,8% памяти. В `top` колонка `RES` — это RSS,
`VIRT` — VSZ. В интерактивном `top` сортировку по памяти включает клавиша `M`.

### 4.2 Завершить

```bash
kill 6006
ps -p 6006
#     PID TTY          TIME CMD
# (строк нет, код возврата 1: процесса больше нет)

systemctl is-active lab-memhog.service
# inactive

free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         385        1087           7         318        1262
# Swap:              0           0           0
```

SIGTERM хватило: процесс завершился, память вернулась (`available` снова 1262).

### 4.3 SIGKILL и его след

Если процесс на SIGTERM не реагирует, остаётся SIGKILL. Запустите службу той же
командой ещё раз и завершите процесс по имени:

```bash
pkill -9 -f memhog.py
pgrep -af memhog
# (пусто, код возврата 1)

systemctl status lab-memhog.service --no-pager | head -n 7
# × lab-memhog.service - [systemd-run] /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
#      Loaded: loaded (/run/systemd/transient/lab-memhog.service; transient)
#   Transient: yes
#      Active: failed (Result: signal) since Mon 2026-10-05 13:53:29 UTC; 2s ago
#    Duration: 3.025s
#  Invocation: a7988faa11824bfba4126f4783f61620
#     Process: 6031 ExecStart=/usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900 (code=killed, signal=KILL)

systemctl is-system-running
# degraded

systemctl reset-failed lab-memhog.service
systemctl is-system-running
# running
```

После SIGTERM служба считалась остановленной штатно (`inactive`). После SIGKILL она
помечена как упавшая (`failed`, `signal=KILL`), и вся система перешла в состояние
`degraded`, пока отметку не сбросили командой `systemctl reset-failed`.

**Контрольные вопросы**

1. Какими двумя командами найти процесс, который занимает больше всего памяти?
2. Чем `kill <PID>` отличается от `kill -9 <PID>` и с чего начинают?
3. Почему после `pkill -9` система оказалась в состоянии `degraded`?

---

## Часть 5: Когда памяти не хватает

### Теория для изучения перед частью

- Если обещанная память понадобилась, а выдать её нечем, ядро выбирает процесс и
  убивает его — это OOM killer. Запись об этом остаётся в журнале ядра.
- Предел можно поставить и одной группе процессов (cgroup): `systemd-run -p
  MemoryMax=<размер>`. Тогда при превышении ядро убивает процесс **этой** группы, а
  остальная система не страдает. Так в модуле и сделано.
- Процесс, убитый ядром, завершается с кодом 137 (128 + 9, SIGKILL).
- Насколько процесс «привлекателен» для OOM killer, видно в `/proc/<PID>/oom_score`;
  поправку задаёт `oom_score_adj` (от −1000 до 1000).
- Источники: `man systemd.resource-control` (MemoryMax, MemorySwapMax),
  `man systemd-run`, `man journalctl`.

### 5.1 Предел памяти для одного процесса

В пределах лимита процесс работает как обычно:

```bash
systemd-run --scope -p MemoryMax=200M -p MemorySwapMax=0 ./memhog.py 150 --touch
# Running as unit: run-p5575-i5576.scope; invocation ID: d9e0c4439ab4484d9c3deae009db70f7
# pid 5575, запрос 150 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1229  Committed_AS=  234
# после mmap     VmSize=  164  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1229  Committed_AS=  384
# после записи   VmSize=  164  VmRSS=  160  VmSwap=    0  |  MemAvailable= 1081  Committed_AS=  384
```

А теперь попросим вдвое больше лимита:

```bash
systemd-run --scope --unit=lab-oom -p MemoryMax=200M -p MemorySwapMax=0 ./memhog.py 400 --touch
# Running as unit: lab-oom.scope; invocation ID: 0bf45b5dd022495b986a9ed460b8a93d
# pid 12691, запрос 400 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1234  Committed_AS=  307
# после mmap     VmSize=  414  VmRSS=   11  VmSwap=    0  |  MemAvailable= 1234  Committed_AS=  707
# Killed
echo $?
# 137
```

Запрос на 400 МиБ прошёл — обещать можно сколько угодно (часть 3). Процесс погиб на
записи, когда его настоящая память дошла до 200 МиБ. Свободной памяти в системе при
этом было больше гигабайта: сработал предел группы, а не нехватка памяти в машине.

### 5.2 Что осталось в журнале

```bash
journalctl -k --since "-1min" --no-pager -o cat | grep -E 'invoked oom-killer|oom-kill:|Memory cgroup out of memory'
# python3 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
# oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/lab-oom.scope,task_memcg=/system.slice/lab-oom.scope,task=python3,pid=12691,uid=0
# Memory cgroup out of memory: Killed process 12691 (python3) total-vm:424804kB, anon-rss:204168kB, file-rss:6128kB, shmem-rss:0kB, UID:0 pgtables:460kB oom_score_adj:0

systemctl status lab-oom.scope --no-pager | head -n 7
# × lab-oom.scope - [systemd-run] /home/ec2-user/rhel-labs/03-memory/memhog.py 400 --touch
#      Loaded: loaded (/run/systemd/transient/lab-oom.scope; transient)
#   Transient: yes
#      Active: failed (Result: oom-kill) since Mon 2026-10-05 14:18:46 UTC; 17ms ago
#    Duration: 132ms
#  Invocation: 0bf45b5dd022495b986a9ed460b8a93d
#    Mem peak: 200M

systemctl is-system-running
# degraded

systemctl reset-failed lab-oom.scope
systemctl is-system-running
# running
```

Как читать запись ядра:

| Фрагмент | Смысл |
|---|---|
| `constraint=CONSTRAINT_MEMCG` | сработал предел группы, а не нехватка памяти всей системы |
| `oom_memcg=/system.slice/lab-oom.scope` | какая именно группа упёрлась в предел |
| `Killed process 12691 (python3)` | кого убили |
| `total-vm:424804kB` | сколько адресов процессу было обещано (VSZ) |
| `anon-rss:204168kB` | сколько памяти он реально занял — у самого предела |

`systemd` запомнил причину: `Result: oom-kill`, `Mem peak: 200M`. Юнит остаётся в
состоянии `failed`, а система — в `degraded`, пока отметку не сбросить.

Какие процессы ядро защищает, видно по поправке:

```bash
cat /proc/1/oom_score_adj /proc/$(pgrep -o sshd)/oom_score_adj
# 0
# -1000
```

У главного процесса `sshd` поправка −1000: OOM killer его не тронет, чтобы на машину
можно было войти даже при нехватке памяти.

**Контрольные вопросы**

1. Процесс завершился с кодом 137. Что это значит и где искать причину?
2. Как по записи в журнале отличить предел группы от нехватки памяти всей системы?
3. Почему запрос на 400 МиБ при лимите 200 МиБ не был отклонён сразу?

---

## Часть 6: Swap

### Теория для изучения перед частью

- Цель экзамена: *Add new partitions and logical volumes, and swap to a system
  non-destructively*. «Non-destructively» — не затрагивая существующие разделы и
  данные: берём пустой диск.
- Swap — место на диске, куда ядро вытесняет давно не использовавшиеся страницы,
  когда памяти не хватает (документация RHEL 10 «Managing storage devices»,
  раздел 13.1).
- Порядок из раздела 13.4: создать раздел, `mkswap`, строка в `/etc/fstab`,
  `systemctl daemon-reload`, `swapon`, проверка `cat /proc/swaps` и `free -h`.
- Строка в `/etc/fstab` (раздел 13.3): `UUID=<uuid> none swap defaults 0 0`.
- Разделы создаём `parted` (там же, разделы 4.1 и 4.3): `mklabel gpt`, затем
  `mkpart <имя> <тип> <начало> <конец>`. В таблице GPT у раздела обязательно есть
  имя; файловую систему `parted` не создаёт.

### 6.1 Раздел на пустом диске

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
# NAME         SIZE TYPE FSTYPE MOUNTPOINTS
# nvme1n1        5G disk        
# nvme0n1       20G disk        
# ├─nvme0n1p1    1M part        
# ├─nvme0n1p2  200M part vfat   /boot/efi
# └─nvme0n1p3 19.8G part xfs    /
# nvme2n1        5G disk        

parted /dev/nvme1n1 print
# Error: /dev/nvme1n1: unrecognised disk label
# Model: Amazon Elastic Block Store (nvme)
# Disk /dev/nvme1n1: 5369MB
# Sector size (logical/physical): 512B/512B
# Partition Table: unknown
# Disk Flags: 
```

Пустые диски — те, у которых нет ни разделов, ни типа файловой системы: `nvme1n1` и
`nvme2n1`. Системный диск — тот, где `/`. **Сверьтесь с `lsblk` перед каждой
командой**: на этом стенде имена `nvme` между перезагрузками меняются. При подготовке
материалов системный диск в одной загрузке был `nvme0n1`, в другой — `nvme2n1`.

```bash
parted -s /dev/nvme1n1 mklabel gpt
parted -s /dev/nvme1n1 mkpart labswap linux-swap 1MiB 1025MiB
udevadm settle
parted /dev/nvme1n1 print
# Model: Amazon Elastic Block Store (nvme)
# Disk /dev/nvme1n1: 5369MB
# Sector size (logical/physical): 512B/512B
# Partition Table: gpt
# Disk Flags: 
#
# Number  Start   End     Size    File system  Name     Flags
#  1      1049kB  1075MB  1074MB               labswap  swap

lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL /dev/nvme1n1
# NAME        SIZE TYPE FSTYPE PARTLABEL
# nvme1n1       5G disk        
# └─nvme1n1p1   1G part        labswap
```

Ключ `-s` — неинтерактивный режим: те же команды `mklabel` и `mkpart`, что в
документации вводятся в приглашении `(parted)`. Имя раздела `labswap` выбрано не
случайно: по нему раздел находят скрипты модуля.

### 6.2 Область подкачки и её включение

```bash
mkswap /dev/nvme1n1p1
# Setting up swapspace version 1, size = 1024 MiB (1073737728 bytes)
# no label, UUID=53a00af0-b460-4ed0-a2a0-4ec3b686ee94

swapon -v /dev/nvme1n1p1
# swapon: /dev/nvme1n1p1: found signature [pagesize=4096, signature=swap]
# swapon: /dev/nvme1n1p1: pagesize=4096, swapsize=1073741824, devsize=1073741824
# swapon /dev/nvme1n1p1

swapon --show
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme1n1p1 partition 1024M   0B   -2

cat /proc/swaps
# Filename				Type		Size		Used		Priority
# /dev/nvme1n1p1                          partition	1048572		0		-2

free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         396         915           7         482        1250
# Swap:           1023           0        1023

grep -E '^(SwapTotal|CommitLimit):' /proc/meminfo
# SwapTotal:       1048572 kB
# CommitLimit:     1891988 kB
```

Swap работает, и `CommitLimit` вырос с 843416 до 1891988 кБ — ровно на размер swap.
Но это до первой перезагрузки: `swapon` — действие на текущий сеанс.

### 6.3 Сделать постоянным

UUID берём из вывода `mkswap` или у `blkid`:

```bash
blkid /dev/nvme1n1p1
# /dev/nvme1n1p1: UUID="53a00af0-b460-4ed0-a2a0-4ec3b686ee94" TYPE="swap" PARTLABEL="labswap" PARTUUID="7aad1292-c8c2-42e0-920a-0e95b66f96e0"

swapoff -v /dev/nvme1n1p1
# swapoff /dev/nvme1n1p1

echo 'UUID=53a00af0-b460-4ed0-a2a0-4ec3b686ee94 none swap defaults 0 0' >> /etc/fstab
tail -n 1 /etc/fstab
# UUID=53a00af0-b460-4ed0-a2a0-4ec3b686ee94 none swap defaults 0 0

findmnt --verify
# 0 parse errors, 0 errors, 1 warning
#    [W] your fstab has been modified, but systemd still uses the old version;
#        use 'systemctl daemon-reload' to reload

systemctl daemon-reload
swapon -a
swapon --show
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme1n1p1 partition 1024M   0B   -2

free -h
#                total        used        free      shared  buff/cache   available
# Mem:           1.6Gi       404Mi       899Mi       7.9Mi       492Mi       1.2Gi
# Swap:          1.0Gi          0B       1.0Gi
```

`swapon -a` подключает всё, что описано в `/etc/fstab`. Если после него swap
появился — строка верна, и можно перезагружаться. Именно поэтому мы сначала
отключили swap: иначе проверять было бы нечего.

Две ошибки, пойманные на стенде при подготовке:

```bash
lsblk -no UUID /dev/nvme1n1p1             # сразу после mkswap
# (пустая строка: lsblk ещё не знает про новую сигнатуру — нужен udevadm settle)

swapon -a                                 # когда в fstab попала строка «UUID= none swap defaults 0 0»
# swapon: cannot open UUID=: No such file or directory
```

Пустой UUID, подставленный в `/etc/fstab` скриптом, даёт нерабочую строку. Перед
перезагрузкой всегда смотрите на строку глазами и проверяйте её командами
`findmnt --verify` и `swapon -a`.

### 6.4 Перезагрузиться и доказать

Перед перезагрузкой запомните имя раздела и посмотрите, что обещает сводка:

```bash
swapon --show
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme2n1p1 partition 1024M   0B   -2

./run.sh | tail -n 2
# === Что будет после перезагрузки ===
# [OK] swap /dev/nvme2n1p1 прописан в /etc/fstab по UUID — после перезагрузки подключится сам

systemctl reboot
```

После входа:

```bash
swapon --show
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme0n1p1 partition 1024M   0B   -2

free -h
#                total        used        free      shared  buff/cache   available
# Mem:           1.6Gi       240Mi       1.2Gi       6.5Mi       217Mi       1.4Gi
# Swap:          1.0Gi          0B       1.0Gi

lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,SERIAL
# NAME         SIZE TYPE FSTYPE PARTLABEL SERIAL
# nvme0n1        5G disk                  vol026abf1eaef5fbb15
# └─nvme0n1p1    1G part swap   labswap   
# nvme2n1       20G disk                  vol0b44f4edb508e17e4
# ├─nvme2n1p1    1M part                  
# ├─nvme2n1p2  200M part vfat             
# └─nvme2n1p3 19.8G part xfs              
# nvme1n1        5G disk                  vol0ed094b9462cbadc2
```

Swap подключился сам, без вашего участия. И посмотрите на имя: до перезагрузки
раздел назывался `/dev/nvme2n1p1`, после — `/dev/nvme0n1p1`. Диск тот же, это видно
по серийному номеру `vol026abf1eaef5fbb15`. За семь загрузок, в которых имя проверялось, этот диск
побывал и `nvme0n1`, и `nvme1n1`, и `nvme2n1` (в шагах 6.1–6.3, снятых днём раньше,
он `nvme1n1`). Строка с именем устройства в `/etc/fstab` на таком стенде работала
бы через раз — строка с UUID работает всегда.

### 6.5 Подкачка в деле

Дадим процессу 150 МиБ памяти и попросим его занять 300 — теперь, со swap:

```bash
systemd-run --scope --unit=lab-swapdemo -p MemoryMax=150M ./memhog.py 300 --touch --hold 3
# Running as unit: lab-swapdemo.scope; invocation ID: b5b607453f4a4564b6ec97de00cf311e
# pid 11329, запрос 300 МиБ, страница 4096 байт
# старт          VmSize=   14  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1242  Committed_AS=  341
# после mmap     VmSize=  314  VmRSS=   10  VmSwap=    0  |  MemAvailable= 1242  Committed_AS=  641
# после записи   VmSize=  314  VmRSS=  152  VmSwap=  158  |  MemAvailable=  970  Committed_AS=  641
# перед выходом  VmSize=  314  VmRSS=  152  VmSwap=  158  |  MemAvailable=  971  Committed_AS=  641

vmstat -s -S M | grep 'pages swapped'
#          1200 pages swapped in
#         40769 pages swapped out
```

В части 5 такой же запрос сверх лимита кончился убийством процесса — там мы запретили
группе swap (`MemorySwapMax=0`). Здесь процесс выжил: 152 МиБ лежат в памяти, 158 —
вытеснены на диск (`VmSwap`). 40769 страниц по 4 КиБ — это те самые ~159 МиБ. Цена —
скорость: обращение к вытесненной странице идёт через диск.

**Контрольные вопросы**

1. Какие три шага превращают пустой раздел в работающий swap и какой четвёртый
   делает его постоянным?
2. Почему в `/etc/fstab` пишут UUID, а не `/dev/nvme1n1p1`?
3. Как проверить строку в `/etc/fstab`, не перезагружаясь?
4. Чем закончился запрос 300 МиБ при пределе 150 МиБ со swap и без него?

---

## Часть 7: Troubleshooting

### Теория: диагностика по симптому

```text
Проблема с памятью
├─ памяти мало (available в free маленький)
│  ├─ ps --sort=-rss: один процесс с большим RSS      → найти и завершить (часть 4)
│  │  └─ после kill он вернулся с новым PID           → это служба с Restart=: systemctl stop (инцидент 1)
│  └─ большой только buff/cache                       → это кеш, не проблема (часть 1.2)
├─ процесс исчез сам, код возврата 137
│  └─ journalctl -k | grep -i 'out of memory'
│     ├─ constraint=CONSTRAINT_MEMCG                  → сработал предел группы (MemoryMax)
│     └─ другой constraint                            → памяти не хватило всей системе
├─ система в состоянии degraded после опытов
│  └─ systemctl --failed                              → systemctl reset-failed <юнит>
└─ swap
   ├─ был и пропал после перезагрузки                 → нет строки в /etc/fstab (инцидент 2)
   ├─ swapon -a: cannot open UUID=...                 → неверный или пустой UUID в строке
   └─ findmnt --verify предупреждает про старую версию → systemctl daemon-reload
```

Порядок проверки: `free -m` (хватает ли) → `ps --sort=-rss` (кто занял) →
`journalctl -k` (что сделало ядро) → `swapon --show` и `/etc/fstab` (что с
подкачкой). `./run.sh` собирает всё это на одном экране.

### Инцидент 1: процесс убили, а он вернулся

Разбор и воспроизведение — в `broken/scenario-01/README.md`, исправление —
`solutions/01-respawning-hog/fix.sh`.

### Инцидент 2: swap пропал после перезагрузки

Разбор и воспроизведение — в `broken/scenario-02/README.md`, исправление —
`solutions/02-swap-not-persistent/fix.sh`.

---

## Проверка модуля

```bash
sudo ./scripts/qa/run-module.sh 03-memory
# --- module: 03-memory ---
# prepare...
# [OK] стенд готов: память 1647 МиБ, доступно 1394 МиБ, swap 0 МиБ, пустых дисков 1, раздел labswap: /dev/nvme2n1p1
# verify...
# [OK] запрос памяти: VmSize +200 МиБ, VmRSS +0 МиБ — страницы ещё не выданы
# [OK] запись в страницы: VmRSS +200 МиБ — память выдана при первом обращении
# [OK] overcommit: запрос 3294 МиБ (вдвое больше RAM и swap) ядро отклоняет сразу
# [OK] поиск: ps --sort=-rss ставит учебный процесс (PID 7066, 211 МиБ) первым
# [OK] kill: процесс завершён по SIGTERM, память возвращена
# [OK] Restart=always: после kill процесс возвращается (PID 7085 -> 7104), останавливает его только systemctl stop
# [OK] предел cgroup: процесс убит (код 137), в журнале ядра «Memory cgroup out of memory»
# [OK] swap: swapon /dev/nvme2n1p1 добавляет 1023 МиБ, swapoff возвращает как было
# [OK] module 03-memory verified
# [OK] учебные процессы остановлены, lab-memhog.service неактивен
# [DRY-RUN] был бы удалён раздел: /dev/nvme2n1p1 (номер 1 на /dev/nvme2n1,    1G, PARTLABEL=labswap, TYPE=swap)
# [WARN] раздел labswap остаётся; удаляет его только запуск с ключом: sudo ./verify/cleanup.sh --apply
# [OK] cleanup 03-memory (dry-run)
```

Этот вывод снят, когда раздел `labswap` уже существовал. На стенде без него вместо
строки про swap будет `[WARN] раздела labswap нет — проверку swap пропускаю (раздел
создаётся руками в части 6)`, а уборка закончится строкой `[OK] раздела labswap нет,
строки в /etc/fstab нет`.

`run-module.sh` делает `prepare → verify → cleanup`. Проверка машину не
перезагружает и разделы не создаёт: если раздела `labswap` ещё нет, шаг про swap
пропускается с пометкой `[WARN]`. Если учебный процесс уже запущен или доступной
памяти меньше 700 МиБ, `verify.sh` откажется работать и ничего не тронет.

Проверку «после перезагрузки» скрипт сделать не может — её делаете вы, по шагу 6.4.

---

## Финальная карта ресурсов модуля

| Ресурс | Что это | Демонстрирует |
|---|---|---|
| `/proc/meminfo`, `free`, `vmstat` | память системы | свободно, кеш, доступно, подкачка |
| `/proc/<PID>/maps`, `pmap` | карта адресного пространства | из каких областей состоит процесс |
| `/proc/<PID>/status` (`VmSize`, `VmRSS`, `VmSwap`) | размеры процесса | обещано, выдано, вытеснено |
| `memhog.py` | учебная программа | разницу между запросом памяти и записью в неё |
| `CommitLimit`, `Committed_AS`, `vm.overcommit_memory` | учёт обещанного | сколько ядро готово пообещать |
| `lab-memhog.service` | учебный процесс как служба | поиск, `kill`, возврат при `Restart=always` |
| `lab-oom.scope` | группа с `MemoryMax` | убийство процесса по пределу и запись в журнале |
| раздел с именем `labswap` | область подкачки на пустом диске | добавление swap без затрагивания данных |
| строка `UUID=… none swap defaults 0 0` в `/etc/fstab` | постоянное подключение | swap после перезагрузки |
| `/var/lib/rhel-labs/03-memory/baseline.txt` | снимок до начала работы | с чем сравнивать |

---

## Теоретические вопросы (итоговые)

1. Чем колонка `available` в `free` отличается от `free` и какой из них верить?
2. Что такое VSZ и RSS и почему они могут различаться в десятки раз?
3. В какой момент ядро на самом деле выдаёт процессу память?
4. Как найти процесс, который занял больше всех памяти, и как его завершить?
5. Процесс убит ядром. По каким признакам в журнале определить причину?
6. Какие шаги нужны, чтобы добавить системе swap на новом разделе так, чтобы он
   пережил перезагрузку?
7. Почему в `/etc/fstab` раздел указывают по UUID?

> Разбор ответов — в `ANSWERS.md`.

---

## Практические задания (отработка)

См. `tasks/`. Каждое задание привязано к цели EX200, названной дословно:

1. **`tasks/01-find-and-kill.md`** — *Identify CPU/memory intensive processes and
   kill processes*.
2. **`tasks/02-add-swap.md`** — *Add new partitions and logical volumes, and swap to
   a system non-destructively*.
3. **`tasks/03-why-was-it-killed.md`** — *Locate and interpret system log files and
   journals*.

---

## Шпаргалка

```bash
# === Память системы ===
free -m                                         # смотреть колонку available
grep -E 'MemAvailable|Cached|Swap|Commit' /proc/meminfo
vmstat 1 5                                      # si/so — движение подкачки

# === Процесс ===
ps -eo pid,user,rss,vsz,pmem,args --sort=-rss | head     # кто занял память
top -b -n 1 -o %MEM | head -n 12                # то же через top (в интерактивном — клавиша M)
grep -E 'VmSize|VmRSS|VmSwap' /proc/<PID>/status
pmap -x <PID> | tail -n 1

# === Завершить ===
kill <PID>                                      # SIGTERM, сначала он
kill -9 <PID>; pkill -9 -f <имя>                # SIGKILL, если не помогло
systemctl stop <служба>                         # если процесс возвращается
systemctl --failed; systemctl reset-failed <юнит>

# === Почему убит ===
journalctl -k | grep -i 'out of memory'

# === Swap на новом разделе ===
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS      # найти пустой диск
parted -s /dev/<диск> mklabel gpt
parted -s /dev/<диск> mkpart <имя> linux-swap 1MiB 1025MiB
udevadm settle
mkswap /dev/<раздел>; blkid /dev/<раздел>
echo 'UUID=<uuid> none swap defaults 0 0' >> /etc/fstab
systemctl daemon-reload; swapon -a
findmnt --verify; swapon --show; free -h
systemctl reboot                                # и проверить ещё раз
```

---

## Чему вы научились

- Читать `free`: отличать кеш от занятой памяти и смотреть на `available`.
- Объяснять разницу между VSZ и RSS и видеть её в `/proc/<PID>/status`.
- Понимать, что память выдаётся при записи, а не при запросе, и что такое overcommit.
- Находить процесс по расходу памяти и завершать его — сигналом или через `systemctl`.
- Находить в журнале ядра причину гибели процесса.
- Добавлять swap на новом разделе, прописывать его по UUID и проверять до и после
  перезагрузки.

---

## Уборка

```bash
sudo ./verify/cleanup.sh
```

Без ключа скрипт останавливает учебные процессы, отключает swap на разделе `labswap`,
убирает его строку из `/etc/fstab` и **показывает**, какой раздел остался, — сам
раздел он не трогает:

```text
[OK] учебные процессы остановлены, lab-memhog.service неактивен
[OK] swap на /dev/nvme1n1p1 отключён
[OK] строка swap UUID=53a00af0-b460-4ed0-a2a0-4ec3b686ee94 убрана из /etc/fstab
[DRY-RUN] был бы удалён раздел: /dev/nvme1n1p1 (номер 1 на /dev/nvme1n1,    1G, PARTLABEL=labswap, TYPE=swap)
[WARN] раздел labswap остаётся; удаляет его только запуск с ключом: sudo ./verify/cleanup.sh --apply
[OK] cleanup 03-memory (dry-run)
```

Удаляет раздел только запуск с ключом, и запускает его человек:

```bash
sudo ./verify/cleanup.sh --apply
```

С `--apply` скрипт стирает сигнатуру swap и удаляет раздел с именем `labswap`. Он
останавливается, если у раздела другое имя, на нём не swap, он используется или
лежит на системном диске. Этот режим при подготовке материалов не запускался.
