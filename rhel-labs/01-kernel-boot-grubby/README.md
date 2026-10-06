# Лабораторная работа 01: параметры ядра и ядро по умолчанию через grubby

## Оглавление
<!-- TOC -->
- [Соответствие целям экзамена RHCSA](#соответствие-целям-экзамена-rhcsa)
- [Предварительные требования](#предварительные-требования)
- [Стартовая проверка](#стартовая-проверка)
- [Часть 1: Откуда ядро берёт параметры](#часть-1-откуда-ядро-берёт-параметры)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью)
  - [1.1 Что работает сейчас и что настроено](#11-что-работает-сейчас-и-что-настроено)
  - [1.2 Файл записи и шаблоны для будущих ядер](#12-файл-записи-и-шаблоны-для-будущих-ядер)
  - [1.3 Какие параметры бывают и кто их читает](#13-какие-параметры-бывают-и-кто-их-читает)
- [Часть 2: Параметр ядра для всех записей](#часть-2-параметр-ядра-для-всех-записей)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-1)
  - [2.1 Добавить параметр](#21-добавить-параметр)
  - [2.2 Перезагрузиться и доказать](#22-перезагрузиться-и-доказать)
  - [2.3 Заменить значение и убрать параметр](#23-заменить-значение-и-убрать-параметр)
- [Часть 3: Параметр для одной записи](#часть-3-параметр-для-одной-записи)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-2)
  - [3.1 Запись работающего ядра](#31-запись-работающего-ядра)
  - [3.2 Запись по умолчанию](#32-запись-по-умолчанию)
- [Часть 4: Ядро по умолчанию](#часть-4-ядро-по-умолчанию)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-3)
  - [4.1 Как на стенде появилось второе ядро](#41-как-на-стенде-появилось-второе-ядро)
  - [4.2 Три вопроса про ядро по умолчанию](#42-три-вопроса-про-ядро-по-умолчанию)
  - [4.3 Сменить ядро по умолчанию по пути](#43-сменить-ядро-по-умолчанию-по-пути)
  - [4.4 Сменить по индексу и ловушка индексов](#44-сменить-по-индексу-и-ловушка-индексов)
  - [4.5 Справочно: разовая загрузка другого ядра](#45-справочно-разовая-загрузка-другого-ядра)
  - [4.6 Разбор: как получается индекс](#46-разбор-как-получается-индекс)
- [Часть 5: Troubleshooting](#часть-5-troubleshooting)
  - [Теория: диагностика по симптому](#теория-диагностика-по-симптому)
  - [Инцидент 1: параметр задан, но после перезагрузки его нет](#инцидент-1-параметр-задан-но-после-перезагрузки-его-нет)
  - [Инцидент 2: после обновления ядра грузится старое](#инцидент-2-после-обновления-ядра-грузится-старое)
- [Проверка модуля](#проверка-модуля)
- [Финальная карта ресурсов модуля](#финальная-карта-ресурсов-модуля)
- [Теоретические вопросы (итоговые)](#теоретические-вопросы-итоговые)
- [Практические задания (отработка)](#практические-задания-отработка)
- [Шпаргалка](#шпаргалка)
- [Чему вы научились](#чему-вы-научились)
- [Уборка](#уборка)
<!-- /TOC -->

> ⏱ время ~90 мин (с 3–5 перезагрузками) · сложность 2/5 · пререквизиты: root на RHEL 10, базовый bash и grep

Цель: научиться менять загрузчик так, как этого требует экзамен RHCSA, — официальным
инструментом `grubby`. Две задачи: задать параметры командной строки ядра (всем
записям загрузчика или одной) и выбрать ядро, которое грузится по умолчанию. Каждую
настройку доводим до конца: перезагружаемся и доказываем на работающей системе, что
она применилась и пережила перезагрузку.

> Все «ожидаемые выводы» сняты 2026-10-05 на стенде `rhel10-lab`: RHEL 10.2, AWS
> `t3.small`, UEFI, `grubby-8.40-83.el10`, ядра `6.12.0-211.53.1.el10_2` и
> `6.12.0-211.61.1.el10_2`. У вас версии ядер, UUID корня и machine-id будут свои —
> важна **структура** вывода. Общая часть параметров стенда
> `console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M`
> в длинных выводах заменена на `<база>`.
>
> Пункты 1.3 и 4.6 сняты на день позже, 2026-10-06. К этому дню на стенде стало три
> ядра (добавилось `6.12.0-211.62.1.el10_2`, оно работает и стоит по умолчанию), а во
> всех записях был параметр `transparent_hugepage=never`.

---

## Соответствие целям экзамена RHCSA

Модуль закрывает цель **Modify the system bootloader** экзамена EX200 (версия для
Red Hat Enterprise Linux 10). Формулировки целей ниже приведены дословно с
[страницы экзамена](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
(сверено 2026-10-05; Red Hat может менять список — перед экзаменом перечитайте страницу).

| Что делаем в модуле | Цель EX200 (дословно) | Раздел целей |
|---|---|---|
| Параметры ядра: добавить, заменить, убрать (части 2–3, задания 01–02) | Modify the system bootloader | Deploy, configure, and maintain systems |
| Ядро по умолчанию (часть 4, задание 03) | Modify the system bootloader | Deploy, configure, and maintain systems |
| Перезагрузка, чтобы применить и проверить настройку | Boot, reboot, and shut down a system normally | Operate running systems |
| Второе ядро на стенде: `dnf upgrade kernel` (4.1) | Install and update software packages from Red Hat Content Delivery Network, a remote repository, or from the local file system | Deploy, configure, and maintain systems |
| `man grubby`, `grubby --help` | Locate, read, and use system documentation including man, info, and files in /usr/share/doc | Understand and use essential tools |
| Фильтрация вывода `grubby --info` | Use grep and regular expressions to analyze text | Understand and use essential tools |

Общее требование экзамена с той же страницы: «As with all Red Hat performance-based
exams, configurations must persist after reboot without intervention». Поэтому любое
задание модуля считается выполненным только после проверки на перезагруженной системе.

Соседние цели, которые модуль **не** закрывает:

- *Interrupt the boot process in order to gain access to a system* — разовая правка
  параметров в меню GRUB клавишей `e`. Нужна консоль машины, это отдельное занятие.
- *Manage tuning profiles* — переменная `$tuned_params`, которую вы увидите в записях,
  принадлежит `tuned`; здесь мы её только замечаем.

---

## Предварительные требования

```bash
sudo -i                                   # всё в модуле делается под root
cd ~ec2-user/rhel-labs/01-kernel-boot-grubby   # sudo -i переносит в /root, вернитесь в каталог модуля
cat /etc/redhat-release; rpm -q grubby
# Red Hat Enterprise Linux release 10.2 (Coughlan)
# grubby-8.40-83.el10.x86_64

ls -1 /boot/vmlinuz-*                     # для части 4 нужно минимум два ядра
# /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64
# /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
```

Если ядро одно — `sudo ./verify/prepare.sh` поставит второе командой
`dnf upgrade kernel` (как это выглядит, показано в 4.1).

Пути вида `./run.sh`, `./verify/…`, `./broken/…` даны от каталога модуля, а
`./scripts/qa/…` — от корня `rhel-labs`. После каждой перезагрузки вход начинается
заново: снова `sudo -i` и `cd` в каталог модуля.

Работаем под root не случайно: каталог `/boot/loader/entries` обычному пользователю
закрыт, и в команде `sudo cat /boot/loader/entries/*.conf` шаблон `*` раскрывает ваша
оболочка, а не `sudo`, — получите `No such file or directory`.

---

## Стартовая проверка

```bash
command -v grubby grub2-editenv >/dev/null && echo "инструменты на месте"
# инструменты на месте

./run.sh | sed -n '/Нужна ли/,$p'         # сводка состояния, ничего не меняет
# === Нужна ли перезагрузка ===
# [OK] работающая система совпадает с конфигурацией загрузчика
```

`./run.sh` целиком показывает работающее ядро, ядро по умолчанию, параметры каждой
записи и расхождения между конфигурацией и работающей системой. Запускайте его в любой
момент, когда запутались, где вы сейчас.

---

## Часть 1: Откуда ядро берёт параметры

### Теория для изучения перед частью

- Параметры ядро получает один раз, при загрузке, от загрузчика. Что получено —
  видно в `/proc/cmdline`. Это единственный источник правды о **работающей** системе.
- В RHEL 10 у каждого установленного ядра своя запись загрузчика — файл
  `/boot/loader/entries/<machine-id>-<версия>.conf` (BootLoaderSpec). Параметры
  лежат в строке `options`.
- `grubby` — штатный инструмент, который читает и правит эти записи. Руками файлы
  не редактируем.
- Источники: документация RHEL 10 «Managing, monitoring, and updating the kernel»,
  разделы 4.1–4.2; `man grubby`.

### 1.1 Что работает сейчас и что настроено

```bash
uname -r
# 6.12.0-211.61.1.el10_2.x86_64

cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M

grubby --info=ALL
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params"
# root="UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1"
# initrd="/boot/initramfs-6.12.0-211.53.1.el10_2.x86_64.img $tuned_initrd"
# title="Red Hat Enterprise Linux (6.12.0-211.53.1.el10_2.x86_64) 10.2 (Coughlan)"
# id="ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params"
# root="UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1"
# initrd="/boot/initramfs-6.12.0-211.61.1.el10_2.x86_64.img $tuned_initrd"
# title="Red Hat Enterprise Linux (6.12.0-211.61.1.el10_2.x86_64) 10.2 (Coughlan)"
# id="ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64"

grubby --info=DEFAULT | grep -E '^(index|kernel)='
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
```

`--info` принимает путь к ядру, слово `ALL` или слово `DEFAULT`. Те же три формы
понимает `--update-kernel`.

### 1.2 Файл записи и шаблоны для будущих ядер

```bash
ls -1 /boot/loader/entries/
# ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64.conf
# ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64.conf

cat /boot/loader/entries/*-$(uname -r).conf
# title Red Hat Enterprise Linux (6.12.0-211.61.1.el10_2.x86_64) 10.2 (Coughlan)
# version 6.12.0-211.61.1.el10_2.x86_64
# linux /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
# initrd /boot/initramfs-6.12.0-211.61.1.el10_2.x86_64.img $tuned_initrd
# options root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params
# grub_users $grub_users
# grub_arg --unrestricted
# grub_class rhel

cat /etc/kernel/cmdline
# root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295

grep GRUB_CMDLINE_LINUX /etc/default/grub
# GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295"

grub2-editenv list
# saved_entry=ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64
# boot_success=1
```

Что здесь важно запомнить:

| Где | Что хранит | Кто читает |
|---|---|---|
| `/proc/cmdline` | параметры работающего ядра | вы, для проверки |
| строка `options` в записи | параметры конкретного ядра на следующую загрузку | GRUB |
| `/etc/kernel/cmdline` | шаблон параметров для ядер, которые поставят позже | установка ядра |
| `GRUB_CMDLINE_LINUX` в `/etc/default/grub` | то же для `grub2-mkconfig` | `grub2-mkconfig` |
| `saved_entry` в окружении GRUB | какая запись грузится по умолчанию | GRUB |

### 1.3 Какие параметры бывают и кто их читает

Закрытого списка «разрешённых» параметров нет. Командную строку читает не одна
программа, а три, и у каждой свой справочник. `man 7 kernel-command-line` начинается с
этого: «The kernel, the programs running in the initrd and in the host system may be
configured at boot via kernel command line arguments».

| Кто читает | Что ему адресовано | Где описано | На стенде |
|---|---|---|---|
| ядро | `console=`, `crashkernel=`, `transparent_hugepage=` и сотни других | файл `kernel-parameters.txt` из пакета `kernel-doc`; `man 7 bootparam` из пакета `man-pages` | пакеты не установлены, оба есть в репозиториях |
| модуль ядра | `модуль.параметр=значение`, например `nvme_core.io_timeout=` | `modinfo -p <модуль>` | есть |
| initramfs (dracut) | `root=` и параметры с приставкой `rd.` | `man 7 dracut.cmdline`; несколько `rd.`-параметров systemd, например `rd.systemd.unit=`, описаны в `man 7 kernel-command-line` | есть |
| systemd и службы основной системы | `systemd.unit=`, `quiet`, `fsck.mode=` и другие | `man 7 kernel-command-line` | есть |

```bash
man -w 7 kernel-command-line
# /usr/share/man/man7/kernel-command-line.7.gz

man -w 7 dracut.cmdline
# /usr/share/man/man7/dracut.cmdline.7.gz

man -w 7 bootparam
# No manual entry for bootparam in section 7

dnf -q list --available kernel-doc man-pages
# Available Packages
# kernel-doc.noarch       6.12.0-211.62.1.el10_2       rhel-10-appstream-rhui-rpms
# man-pages.noarch        6.06-13.el10_2               rhel-10-baseos-rhui-rpms
```

Теперь разберите по словам строку, с которой загружен стенд:

```bash
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M transparent_hugepage=never
```

| Слово | Кто читает | Чем проверить, что сработало |
|---|---|---|
| `BOOT_IMAGE=…` | никто: в записи загрузчика его нет (см. 1.2), его дописывает загрузчик при запуске ядра | строка в журнале ядра, см. ниже |
| `root=UUID=…` | initramfs: найти и смонтировать корень | `findmnt -no SOURCE,UUID /` |
| `console=tty0 console=ttyS0,115200n8` | ядро: куда выводить сообщения | `cat /sys/class/tty/console/active` |
| `nvme_core.io_timeout=4294967295` | модуль ядра `nvme_core` | `cat /sys/module/nvme_core/parameters/io_timeout` |
| `crashkernel=2G-64G:256M,64G-:512M` | ядро: сколько памяти отложить под kdump | `cat /sys/kernel/kexec_crash_size` |
| `transparent_hugepage=never` | ядро | `cat /sys/kernel/mm/transparent_hugepage/enabled` |

```bash
findmnt -no SOURCE,UUID /
# /dev/nvme0n1p3 c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1

cat /sys/class/tty/console/active
# tty0 ttyS0

modinfo -p nvme_core | grep io_timeout
# io_timeout:timeout in seconds for I/O (uint)

cat /sys/module/nvme_core/parameters/io_timeout
# 4294967295

cat /sys/kernel/kexec_crash_size
# 268435456

cat /sys/kernel/mm/transparent_hugepage/enabled
# always madvise [never]
```

`268435456` байт — это 256 МиБ из правила `2G-64G:256M`. Параметр модуля записан в
форме `модуль.параметр=значение`: слева от точки имя модуля, справа — имя из
`modinfo -p`. Подробно модули разбирает лаба `02-kernel-modules`.

Что ядро делает со словом, которого не знает, видно в журнале:

```bash
journalctl -k -b -o cat | grep 'Unknown kernel command line'
# Unknown kernel command line parameters "BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64", will be passed to user space.
```

Ядро незнакомое слово не отвергает, а передаёт дальше, программам. Загрузка от этого
не останавливается. Поэтому в лабе после каждой перезагрузки проверяется не только
`/proc/cmdline`, но и эффект параметра: строка в `/proc/cmdline` доказывает, что слово
дошло, а не что его кто-то понял.

Описание параметра ищут в справочнике того, кто его читает:

```bash
man 7 dracut.cmdline 2>/dev/null | grep -A1 -E '^ +rd\.break$'
#        rd.break
#            drop to a shell at the end
```

`rd.break` останавливает загрузку внутри initramfs и даёт оболочку. Это параметр из
цели экзамена *Interrupt the boot process in order to gain access to a system*; для
него нужна консоль машины, и разбирается он на отдельном занятии.

Полный список параметров самого ядра лежит в пакете `kernel-doc` (45 МБ). Поставить
его и найти описание параметра — три команды:

```bash
dnf -y install kernel-doc man-pages
grep -n -A6 'transparent_hugepage=' /usr/share/doc/kernel-doc-*/Documentation/admin-guide/kernel-parameters.txt
man 7 bootparam
```

Путь к файлу взят из `dnf repoquery -l kernel-doc`. Сами эти три команды при
подготовке материалов **не выполнялись**: пакеты на стенд не ставились, поэтому
выводов здесь нет.

Два уточнения:

- На экзамене параметр назовут в задании. Учить список не нужно. Нужно уметь записать
  параметр через `grubby`, найти его описание и доказать эффект после перезагрузки.
- Командная строка — не единственный способ настроить ядро. Значения в `/proc/sys`
  меняет `sysctl`, на ходу и без перезагрузки (`man 8 sysctl`, `man 5 sysctl.d`). Это
  другой механизм, `grubby` к нему отношения не имеет.

**Контрольные вопросы**

1. Чем `args=` из `grubby --info` отличается от `/proc/cmdline` по смыслу?
2. Почему у двух записей на стенде разные префиксы в имени файла?
3. Какая команда покажет параметры только той записи, что грузится по умолчанию?
4. Кто читает `rd.break`, кто `systemd.unit=`, кто `transparent_hugepage=`? В каком
   справочнике искать каждый?
5. Параметр есть в `/proc/cmdline`. Почему этого мало, чтобы считать его применённым?

---

## Часть 2: Параметр ядра для всех записей

### Теория для изучения перед частью

- Официальные команды (документация RHEL 10, раздел 4.3):
  `grubby --update-kernel=ALL --args="<параметр>"` и
  `grubby --update-kernel=ALL --remove-args="<параметр>"`.
- Изменение записи не трогает работающее ядро. Пока не перезагрузились,
  `/proc/cmdline` прежний.
- В качестве примера берём `transparent_hugepage=never`: у него есть наблюдаемый
  эффект в `/sys/kernel/mm/transparent_hugepage/enabled`, так что можно проверить не
  только строку, но и поведение ядра. На экзамене параметр назовут в задании.

### 2.1 Добавить параметр

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
# [always] madvise never

grubby --update-kernel=ALL --args="transparent_hugepage=never"
# (вывода нет, код возврата 0)

grubby --info=ALL | grep -E '^(index|args)='
# index=0
# args="<база> $tuned_params transparent_hugepage=never"
# index=1
# args="<база> $tuned_params transparent_hugepage=never"
```

С `ALL` grubby обновил ещё и оба шаблона, чтобы параметр достался будущим ядрам:

```bash
cat /etc/kernel/cmdline
# root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 transparent_hugepage=never

grep GRUB_CMDLINE_LINUX /etc/default/grub
# GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 transparent_hugepage=never"
```

А работающая система пока прежняя:

```bash
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=... <база>

cat /sys/kernel/mm/transparent_hugepage/enabled
# [always] madvise never
```

### 2.2 Перезагрузиться и доказать

```bash
systemctl reboot
```

После входа:

```bash
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=... <база> transparent_hugepage=never

cat /sys/kernel/mm/transparent_hugepage/enabled
# always madvise [never]
```

Параметр есть в `/proc/cmdline`, и ядро его исполнило. Это и есть доказательство для
экзамена: настройка пережила перезагрузку без вашего участия.

### 2.3 Заменить значение и убрать параметр

Повторный `--args` с тем же ключом заменяет значение, а не добавляет дубль:

```bash
grubby --update-kernel=ALL --args="transparent_hugepage=madvise"
grubby --info=ALL | grep -E '^(index|args)='
# index=0
# args="<база> $tuned_params transparent_hugepage=madvise"
# index=1
# args="<база> $tuned_params transparent_hugepage=madvise"
```

Удалять можно по одному ключу, значение указывать не нужно:

```bash
grubby --update-kernel=ALL --remove-args="transparent_hugepage"
grubby --info=ALL | grep -E '^(index|args)='
# index=0
# args="<база> $tuned_params"
# index=1
# args="<база> $tuned_params"

cat /etc/kernel/cmdline
# root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295
```

Несколько параметров передаются одной строкой через пробел:
`--args="quiet loglevel=3"`, `--remove-args="quiet loglevel"`.

Две особенности, снятые на стенде:

```bash
grubby --update-kernel=ALL --remove-args="no_such_parameter"; echo "exit code: $?"
# exit code: 0

grubby --update-kernel=/boot/vmlinuz-0.0.0 --args="quiet"; echo "exit code: $?"
# The param /boot/vmlinuz-0.0.0 is incorrect
# exit code: 1
```

Удаление несуществующего параметра ошибкой не считается: опечатка в имени пройдёт
молча. Поэтому после каждой правки смотрите `grubby --info`, а не код возврата.

**Контрольные вопросы**

1. Вы добавили параметр, `grubby --info=ALL` его показывает, а `/proc/cmdline` — нет.
   Что вы забыли?
2. Как изменить значение уже заданного параметра и не получить два значения сразу?
3. Почему проверки по коду возврата `--remove-args` недостаточно?

---

## Часть 3: Параметр для одной записи

### Теория для изучения перед частью

- Официальные команды (раздел 4.4):
  `grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="<параметр>"` и то же с
  `--remove-args`.
- Вместо пути можно написать `DEFAULT` — запись, которая грузится по умолчанию
  (`man grubby`).
- Правка одной записи **не** меняет шаблоны. Ядро, установленное позже, такой
  параметр не получит.

### 3.1 Запись работающего ядра

```bash
grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="quiet"
grubby --info=ALL | grep -E '^(index|args)='
# index=0
# args="<база> $tuned_params transparent_hugepage=madvise"
# index=1
# args="<база> $tuned_params transparent_hugepage=madvise quiet"

cat /etc/kernel/cmdline
# root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 transparent_hugepage=madvise

grubby --update-kernel=/boot/vmlinuz-$(uname -r) --remove-args="quiet"
```

`quiet` попал только в запись с индексом 1, а в `/etc/kernel/cmdline` его нет — там
лишь то, что задавалось через `ALL`. (Вывод снят в момент, когда всем записям ещё
был задан `transparent_hugepage=madvise` из 2.3.)

### 3.2 Запись по умолчанию

```bash
grubby --update-kernel=DEFAULT --args="quiet"
grubby --info=DEFAULT | grep -E '^(index|args)='
# index=1
# args="<база> $tuned_params transparent_hugepage=madvise quiet"

grubby --update-kernel=DEFAULT --remove-args="quiet"
```

`$(uname -r)` и `DEFAULT` — не одно и то же: первое про ядро, которое работает
сейчас, второе про ядро, которое загрузится в следующий раз. После смены ядра по
умолчанию и до перезагрузки они указывают на разные записи.

**Контрольные вопросы**

1. В задании сказано «для всех ядер». Чем плохо решение через
   `--update-kernel=/boot/vmlinuz-$(uname -r)`?
2. В какой момент `--update-kernel=DEFAULT` и `--update-kernel=/boot/vmlinuz-$(uname -r)`
   меняют разные записи?

---

## Часть 4: Ядро по умолчанию

### Теория для изучения перед частью

- Официальные команды (документация RHEL 10, раздел 1.8 «Setting a kernel as
  default»): `grubby --set-default $kernel_path`; список записей —
  `grubby --info=ALL | grep title`.
- Посмотреть текущее: `grubby --default-kernel`, `--default-index`, `--default-title`
  (`man grubby`).
- Выбор хранится в переменной `saved_entry` окружения GRUB; в `/etc/default/grub`
  стоит `GRUB_DEFAULT=saved`.
- Обновление ядра ставится рядом со старым (раздел 1.7: `dnf upgrade kernel`), старое
  не удаляется. На стенде `installonly_limit=3`.

### 4.1 Как на стенде появилось второе ядро

Этот шаг уже выполнен при подготовке стенда; вывод снят в тот момент, когда
единственному ядру был задан `transparent_hugepage=never`. Повторить его можно только
на свежей машине.

```bash
dnf -y upgrade kernel
# Installing:
#  kernel            x86_64 6.12.0-211.61.1.el10_2 rhel-10-baseos-rhui-rpms 1.7 M
#  kernel-core       x86_64 6.12.0-211.61.1.el10_2 rhel-10-baseos-rhui-rpms  19 M
#  kernel-modules    x86_64 6.12.0-211.61.1.el10_2 rhel-10-baseos-rhui-rpms  42 M
#  kernel-modules-core
#                    x86_64 6.12.0-211.61.1.el10_2 rhel-10-baseos-rhui-rpms  31 M
# ...
# Complete!

rpm -q kernel
# kernel-6.12.0-211.53.1.el10_2.x86_64
# kernel-6.12.0-211.61.1.el10_2.x86_64

grubby --info=ALL | grep -E '^(index|kernel|args)='
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# args="<база> $tuned_params transparent_hugepage=never"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 transparent_hugepage=never crashkernel=2G-64G:256M,64G-:512M $tuned_params"

grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

uname -r
# 6.12.0-211.53.1.el10_2.x86_64
```

Три наблюдения:

1. Новое ядро **унаследовало** `transparent_hugepage=never`. Документация (раздел 4.3)
   это обещает: при установке более нового ядра grubby передаёт ему параметры
   предыдущего. Порядок слов в новой записи совпадает с `/etc/kernel/cmdline`.
2. Новое ядро само стало ядром по умолчанию. На стенде в `/etc/sysconfig/kernel`
   стоит `UPDATEDEFAULT=yes`.
3. Работает по-прежнему старое: до перезагрузки ничего не меняется.

### 4.2 Три вопроса про ядро по умолчанию

```bash
grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

grubby --default-index
# 1

grubby --default-title
# Red Hat Enterprise Linux (6.12.0-211.61.1.el10_2.x86_64) 10.2 (Coughlan)

grubby --info=ALL | grep -E '^(index|kernel|title)='
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# title="Red Hat Enterprise Linux (6.12.0-211.53.1.el10_2.x86_64) 10.2 (Coughlan)"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
# title="Red Hat Enterprise Linux (6.12.0-211.61.1.el10_2.x86_64) 10.2 (Coughlan)"
```

### 4.3 Сменить ядро по умолчанию по пути

```bash
grubby --set-default /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64
# The default is /boot/loader/entries/ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64.conf with index 0 and kernel /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64

grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64

grub2-editenv list
# saved_entry=ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64
# boot_success=1

uname -r                                  # работает пока прежнее
# 6.12.0-211.61.1.el10_2.x86_64

systemctl reboot
```

После входа:

```bash
uname -r
# 6.12.0-211.53.1.el10_2.x86_64
```

### 4.4 Сменить по индексу и ловушка индексов

```bash
grubby --set-default-index=1
# The default is /boot/loader/entries/ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64.conf with index 1 and kernel /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

systemctl reboot
# после входа:
uname -r
# 6.12.0-211.61.1.el10_2.x86_64
```

На этом стенде индекс 0 — **старое** ядро, а новое получило индекс 1. Причина видна в
самом `grubby` (это shell-скрипт `/usr/sbin/grubby`, строки 88–95 в версии
8.40-83.el10): записи нумеруются по именам файлов после `sort -Vr`. Запись старого
ядра создана в образе с machine-id из одних `f`, новая — с настоящим
`/etc/machine-id` (`ec2e861e…`), и строка `ffff…` при обратной сортировке идёт
первой. Документация предупреждает о том же (раздел 1.8): установка новых ядер может
менять значения индексов.

Вывод для экзамена: ядро по умолчанию задавайте **путём** (`--set-default
/boot/vmlinuz-<версия>`), а индекс используйте, только посмотрев перед этим
`grubby --info=ALL`. Как индекс получается шаг за шагом — в пункте 4.6.

Ошибка в пути или индексе ничего не ломает:

```bash
grubby --set-default /boot/vmlinuz-0.0.0; echo "exit code: $?"
# The param /boot/vmlinuz-0.0.0 is incorrect
# exit code: 1

grubby --set-default-index=7; echo "exit code: $?"
# The param 7 is incorrect
# exit code: 1
```

### 4.5 Справочно: разовая загрузка другого ядра

Этот пункт **вне экзаменационных заданий модуля**: настройка намеренно не
переживает перезагрузку. Он из того же раздела 1.8 документации и полезен, чтобы
проверить ядро, не меняя выбор по умолчанию.

```bash
grub2-reboot 1                            # по умолчанию при этом запись 0
grub2-editenv list
# saved_entry=ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64
# boot_success=1
# next_entry=1

systemctl reboot
# после входа:
uname -r
# 6.12.0-211.61.1.el10_2.x86_64
grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64
grub2-editenv list
# saved_entry=ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64
# boot_success=1
# next_entry=
```

`next_entry` сработал один раз и очистился; следующая перезагрузка вернёт ядро из
`saved_entry`.

### 4.6 Разбор: как получается индекс

Выводы этого пункта сняты 2026-10-06, когда на стенде стало три ядра. Команды только
читают, ничего не меняют и перезагрузки не требуют.

Индекс — не свойство ядра, и он нигде не хранится. Это номер строки в списке записей,
который `grubby` каждый раз строит заново. Шагов три:

1. взять имена файлов из `/boot/loader/entries/`;
2. отсортировать их в обратном порядке с учётом номеров версий (`sort -Vr`);
3. пронумеровать строки, начиная с нуля.

Проделайте это руками и сравните с тем, что печатает `grubby`:

```bash
ls -1 /boot/loader/entries/
# ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64.conf
# ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.62.1.el10_2.x86_64.conf
# ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64.conf

ls -1 /boot/loader/entries/ | sort -Vr | nl -v0
#      0  ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64.conf
#      1  ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.62.1.el10_2.x86_64.conf
#      2  ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64.conf

grubby --info=ALL | grep -E '^(index|kernel)='
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64"
# index=2
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
```

Номера совпали. Почему порядок именно такой:

- Имена сравниваются целиком, слева направо, и сначала идёт префикс. `ffff…` больше,
  чем `ec2e…`, поэтому при обратной сортировке запись из образа стоит первой. Возраст
  ядра здесь ни при чём.
- У двух записей с одинаковым префиксом решает версия: `62.1` больше `61.1`, значит
  более новое ядро стоит выше.

Отсюда же видно, что на машине, где у всех записей один префикс, индекс 0 достанется
самому новому ядру. На стенде порядок сбивает только запись из образа.

Теперь сравните со вчерашним днём (вывод в 4.2):

| Индекс | 2026-10-05, два ядра | 2026-10-06, три ядра |
|---|---|---|
| 0 | `…53.1` | `…53.1` |
| 1 | `…61.1` | `…62.1` |
| 2 | — | `…61.1` |

Третье ядро встало в середину списка и сдвинуло `…61.1` с первого места на второе.
Вчера `--set-default-index=1` выбирал `…61.1` (вывод в 4.4). Сегодня под номером 1
стоит другое ядро. Об этом и предупреждает раздел 1.8 документации.

Что хранится на самом деле:

```bash
grub2-editenv list
# saved_entry=ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.62.1.el10_2.x86_64
# boot_success=1

grubby --default-index
# 1
```

В `saved_entry` записано имя записи, а не номер. `--default-index` находит это имя в
списке и печатает номер его строки. `--set-default-index=N` работает в обратную
сторону: берёт строку N и записывает её имя (в 4.4 это видно по сообщению
`The default is …`).

Три правила, которых достаточно:

1. Индекс — номер строки в отсортированном списке записей, счёт с нуля.
2. Номер принадлежит месту в списке, а не ядру: поставили или удалили ядро — номера
   сдвинулись.
3. Перед любой командой с индексом смотрите `grubby --info=ALL`. Путь к ядру от
   списка не зависит, поэтому он надёжнее.

Проверьте себя, ничего не выполняя:

1. Со стенда удалили ядро `…53.1`. Какие индексы получат два оставшихся?
2. На машине с одним префиксом у всех записей стоят ядра `…61.1`, `…62.1` и `…63.1`.
   У какого из них индекс 0?
3. В скрипте, написанном вчера, есть строка `grubby --set-default-index=1`. Какое
   ядро он выберет на стенде сегодня?

**Контрольные вопросы**

1. Назовите три команды, отвечающие на вопрос «какое ядро загрузится следующим».
2. Почему `--set-default-index=0` на этом стенде выбирает не самое новое ядро?
3. Вы поставили обновление ядра и не перезагружались. Что покажут `uname -r` и
   `grubby --default-kernel`?
4. Чем `grub2-reboot` не подходит для экзаменационного задания «сделать ядро ядром
   по умолчанию»?
5. Что записано в `saved_entry`: номер записи или её имя? Что из этого следует для
   индекса?

---

## Часть 5: Troubleshooting

### Теория: диагностика по симптому

```text
Настройка «не работает» после перезагрузки
├─ параметра нет в /proc/cmdline
│  ├─ grubby --info=DEFAULT его не показывает
│  │  ├─ он есть в другой записи      → задан одной записи, а не ALL (инцидент 1)
│  │  └─ его нет нигде                → опечатка в имени или не та команда
│  └─ grubby --info=DEFAULT показывает → не перезагружались после правки
└─ uname -r показывает не то ядро
   ├─ grubby --default-kernel = то, что загрузилось → выбрано не то ядро (инцидент 2)
   └─ grubby --default-kernel = нужное ядро         → не перезагружались, либо
                                                       сработал разовый next_entry
```

Порядок проверки всегда один: `/proc/cmdline` и `uname -r` (что работает) →
`grubby --info=DEFAULT` и `grubby --default-kernel` (что настроено) → сравнить.
`./run.sh` делает это сравнение сам.

### Инцидент 1: параметр задан, но после перезагрузки его нет

Разбор и воспроизведение — в `broken/scenario-01/README.md`, исправление —
`solutions/01-param-one-entry/fix.sh`.

### Инцидент 2: после обновления ядра грузится старое

Разбор и воспроизведение — в `broken/scenario-02/README.md`, исправление —
`solutions/02-default-pinned/fix.sh`.

---

## Проверка модуля

```bash
sudo ./scripts/qa/run-module.sh 01-kernel-boot-grubby
# --- module: 01-kernel-boot-grubby ---
# prepare...
# [OK] стенд готов: ядер 2, по умолчанию /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64, снимок /var/lib/rhel-labs/01-kernel-boot-grubby/baseline.txt
# verify...
# [OK] --update-kernel=ALL --args: transparent_hugepage=never в 2 записях из 2
# [OK] ALL обновил и шаблоны: /etc/kernel/cmdline и GRUB_CMDLINE_LINUX
# [OK] до перезагрузки /proc/cmdline прежний: работающее ядро параметра не видит
# [OK] повторный --args с тем же ключом заменяет значение, а не дублирует
# [OK] --update-kernel=<путь>: параметр только в одной записи, шаблоны не тронуты
# [OK] --remove-args по ключу убирает параметр вместе со значением, шаблоны очищены
# [OK] --remove-args несуществующего параметра завершается с кодом 0
# [OK] --set-default <путь>: default-kernel, default-index и saved_entry согласованы
# [OK] --set-default-index=1 вернул исходное ядро по умолчанию
# [OK] ошибка в пути или индексе: код 1, ядро по умолчанию не меняется
# [OK] module 01-kernel-boot-grubby verified
# [OK] записи загрузчика без параметров лабы, по умолчанию /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
# [OK] cleanup 01-kernel-boot-grubby
```

`run-module.sh` делает `prepare → verify → cleanup`. Проверка идёт на уровне
конфигурации загрузчика и машину не перезагружает; в конце она возвращает записи в
исходное состояние. Если в записях уже есть параметры лабы, `verify.sh` откажется
работать и попросит сначала выполнить `cleanup.sh` — чтобы не стереть вашу
незаконченную работу молча.

Проверку «после перезагрузки» скрипт сделать не может — её делаете вы, по шагам 2.2
и 4.3.

---

## Финальная карта ресурсов модуля

| Ресурс | Что это | Демонстрирует |
|---|---|---|
| `/proc/cmdline` | параметры работающего ядра | что действует сейчас |
| `/boot/loader/entries/*.conf` | записи загрузчика, строка `options` | что применится при следующей загрузке |
| `/etc/kernel/cmdline`, `GRUB_CMDLINE_LINUX` | шаблоны параметров | что унаследуют будущие ядра (меняет только `ALL`) |
| `saved_entry` в `grub2-editenv list` | идентификатор записи по умолчанию | где хранится выбор `--set-default` |
| `next_entry` там же | разовый выбор `grub2-reboot` | настройку, которая не переживает перезагрузку |
| `/sys/kernel/mm/transparent_hugepage/enabled` | состояние THP | что ядро исполнило параметр |
| `/var/lib/rhel-labs/01-kernel-boot-grubby/baseline.txt` | снимок до начала работы | с чем сравнивать |

---

## Теоретические вопросы (итоговые)

1. Где смотреть параметры работающего ядра, а где — настроенные на следующую загрузку?
2. Что именно меняет `grubby --update-kernel=ALL --args=...`, кроме записей загрузчика?
3. Чем правка одной записи отличается от `ALL` по последствиям для будущих ядер?
4. Где хранится выбор ядра по умолчанию и какие три команды его показывают?
5. Почему ядро по умолчанию надёжнее задавать путём, а не индексом?
6. Какое требование экзамена делает перезагрузку обязательной частью каждого задания?
7. Кто читает командную строку ядра и где искать описание параметра, который вы
   видите впервые?
8. Что такое индекс записи, как он получается и где хранится?

> Разбор ответов — в `ANSWERS.md`.

---

## Практические задания (отработка)

См. `tasks/`. Каждое задание сформулировано как на экзамене и привязано к цели EX200
**Modify the system bootloader**:

1. **`tasks/01-param-all-kernels.md`** — задать параметр ядра всем записям и доказать
   после перезагрузки.
2. **`tasks/02-param-change-and-remove.md`** — заменить значение, задать параметр
   одной записи, убрать всё лишнее.
3. **`tasks/03-default-kernel.md`** — сделать заданное ядро ядром по умолчанию и
   вернуть обратно.

---

## Шпаргалка

```bash
# === Посмотреть ===
cat /proc/cmdline                               # что действует сейчас
grubby --info=ALL                               # все записи
grubby --info=DEFAULT                           # запись по умолчанию
grubby --default-kernel                         # путь ядра по умолчанию
grubby --default-index; grubby --default-title

# === Параметры ядра ===
grubby --update-kernel=ALL --args="ключ=значение"          # всем записям и в шаблоны
grubby --update-kernel=ALL --remove-args="ключ"            # убрать у всех
grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="ключ"   # одной записи
grubby --update-kernel=DEFAULT --args="ключ"               # записи по умолчанию

# === Ядро по умолчанию ===
grubby --set-default /boot/vmlinuz-<версия>     # надёжно: по пути
grubby --set-default-index=<N>                  # только сверившись с --info=ALL
ls -1 /boot/loader/entries/ | sort -Vr | nl -v0 # откуда берутся индексы

# === Что значит параметр ===
man 7 kernel-command-line                       # параметры systemd и служб
man 7 dracut.cmdline                            # параметры initramfs: root=, rd.*
modinfo -p <модуль>                             # параметры модуля: модуль.параметр=значение
journalctl -k -b -o cat | grep 'Unknown kernel command line'   # слова, которых ядро не знает

# === Применить и доказать ===
systemctl reboot
cat /proc/cmdline; uname -r
```

---

## Чему вы научились

- Различать параметры работающего ядра (`/proc/cmdline`) и настроенные на следующую
  загрузку (`grubby --info`).
- Добавлять, заменять и убирать параметры ядра официальными командами `grubby` — для
  всех записей и для одной.
- Понимать, что `ALL` обновляет шаблоны для будущих ядер, а правка одной записи — нет.
- Смотреть и менять ядро по умолчанию, не попадаясь в ловушку индексов.
- Объяснять, откуда берётся индекс записи, и получать его руками из списка файлов.
- Определять, кто читает параметр командной строки — ядро, модуль, initramfs или
  systemd, — и находить его описание в нужном справочнике.
- Доводить настройку до требования экзамена: проверка после перезагрузки.

---

## Уборка

```bash
sudo ./verify/cleanup.sh
# [OK] записи загрузчика без параметров лабы, по умолчанию /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
# [OK] cleanup 01-kernel-boot-grubby
```

`cleanup.sh` убирает из всех записей параметры лабы (`transparent_hugepage`, `quiet`,
`loglevel`), сбрасывает разовый `next_entry` и делает ядром по умолчанию самое новое.
Файлы он не удаляет. Если работающая система ещё загружена со старыми настройками,
скрипт напишет об этом — тогда перезагрузитесь:

```text
[WARN] работающая система ещё в старом состоянии (ядро 6.12.0-211.61.1.el10_2.x86_64, параметры: transparent_hugepage) — перезагрузись: systemctl reboot
```
