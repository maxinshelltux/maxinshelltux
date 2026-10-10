# Лабораторная работа 05: systemd — загрузка в разные target'ы и анализ загрузки

## Оглавление
<!-- TOC -->
- [Соответствие целям экзамена RHCSA](#соответствие-целям-экзамена-rhcsa)
- [Откуда взяты команды](#откуда-взяты-команды)
- [Предварительные требования](#предварительные-требования)
- [Стартовая проверка](#стартовая-проверка)
- [Часть 1: Что такое target](#часть-1-что-такое-target)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью)
  - [1.1 Какие target есть и какой активен](#11-какие-target-есть-и-какой-активен)
  - [1.2 Из чего состоит target](#12-из-чего-состоит-target)
- [Часть 2: Переключить target на работающей системе](#часть-2-переключить-target-на-работающей-системе)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-1)
  - [2.1 isolate: сменить target на лету](#21-isolate-сменить-target-на-лету)
  - [2.2 rescue — только с консоли](#22-rescue--только-с-консоли)
  - [2.3 emergency — только с консоли](#23-emergency--только-с-консоли)
- [Часть 3: target по умолчанию и разовый выбор](#часть-3-target-по-умолчанию-и-разовый-выбор)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-2)
  - [3.1 Постоянный target: set-default](#31-постоянный-target-set-default)
  - [3.2 Разовый target: systemd.unit в командной строке ядра](#32-разовый-target-systemdunit-в-командной-строке-ядра)
- [Часть 4: Анализ загрузки (systemd-analyze)](#часть-4-анализ-загрузки-systemd-analyze)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-3)
  - [4.1 Общее время по фазам](#41-общее-время-по-фазам)
  - [4.2 blame: кто дольше поднимался](#42-blame-кто-дольше-поднимался)
  - [4.3 critical-chain: что держало загрузку](#43-critical-chain-что-держало-загрузку)
- [Часть 5: Troubleshooting](#часть-5-troubleshooting)
  - [Теория: диагностика по симптому](#теория-диагностика-по-симптому)
  - [Инцидент 1: машина ушла в rescue и не пускает по SSH](#инцидент-1-машина-ушла-в-rescue-и-не-пускает-по-ssh)
  - [Инцидент 2: get-default говорит multi-user, а грузится rescue](#инцидент-2-get-default-говорит-multi-user-а-грузится-rescue)
- [Как подготовлен стенд](#как-подготовлен-стенд)
- [Проверка модуля](#проверка-модуля)
- [Теоретические вопросы (итоговые)](#теоретические-вопросы-итоговые)
- [Практические задания (отработка)](#практические-задания-отработка)
- [Шпаргалка](#шпаргалка)
- [Чему вы научились](#чему-вы-научились)
- [Уборка](#уборка)
<!-- /TOC -->

> ⏱ время ~60 мин (с 2–3 перезагрузками) · сложность 2/5 · пререквизиты: лаба 01; для частей 2.2–2.3 и инцидентов — консоль стенда (её открывает ментор)

Цель: научиться управлять тем, в каком режиме работает и загружается система, —
переключать target на лету, задавать target по умолчанию, разово выбирать target при
загрузке и читать, из чего складывается время загрузки. Это цель экзамена *Boot systems
into different targets manually*.

> Все «ожидаемые выводы» сняты на стенде `rhel10-lab`: RHEL 10.2, AWS `t3.small`,
> `systemd-257-23.el10_2`. Выводы про target'ы, rescue и emergency сняты 2026-10-05 с
> консоли и по SSH; выводы `systemd-analyze` — 2026-10-10. У вас версии ядер, адреса и
> время загрузки будут свои — важна **структура** вывода.

---

## Соответствие целям экзамена RHCSA

Формулировки целей приведены дословно со
[страницы экзамена EX200](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
(версия для Red Hat Enterprise Linux 10, сверено 2026-10-10; Red Hat может менять
список — перед экзаменом перечитайте страницу).

| Что делаем в модуле | Цель EX200 (дословно) | Раздел целей |
|---|---|---|
| Переключаем target на лету (`isolate`), задаём target по умолчанию (`set-default`), выбираем target разово (`systemd.unit=`) — части 1–3, задания 01–02 | Boot systems into different targets manually | Operate running systems |
| Задаём постоянный target и проверяем перезагрузкой; `systemctl reboot` (часть 3) | Boot, reboot, and shut down a system normally | Operate running systems |
| `systemd.unit=` в записи загрузчика и его удаление через `grubby` (часть 3.2, инцидент 2) | Modify the system bootloader | Deploy, configure, and maintain systems |
| `man 5 systemd.target`, `man 1 systemd-analyze`, разделы документации RHEL 10 | Locate, read, and use system documentation including man, info, and files in /usr/share/doc | Understand and use essential tools |

Общее требование экзамена с той же страницы: «As with all Red Hat performance-based
exams, configurations must persist after reboot without intervention». В этой лабе оно
про `set-default`: выбранный target по умолчанию должен пережить перезагрузку.

Что модуль **не** закрывает отдельной целью: `systemd-analyze` (часть 4) — не цель
EX200, а смежный инструмент из документации RHEL 10. Он здесь, потому что помогает
понимать загрузку и это то, с чего начинается разбор медленного старта.

---

## Откуда взяты команды

Все команды — из документации RHEL 10 «Using systemd unit files to customize and
optimize your system»:

- глава 3 «Booting into a target system state» — `get-default`, `set-default`,
  `isolate`, `systemctl rescue`, разовый `systemd.unit=` в меню GRUB (разделы 3.2–3.5):
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_systemd_unit_files_to_customize_and_optimize_your_system/booting-into-a-target-system-state>
- глава 5 «Optimizing systemd to shorten the boot time», раздел 5.1 — `systemd-analyze`,
  `blame`, `critical-chain`:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_systemd_unit_files_to_customize_and_optimize_your_system/optimizing-systemd-to-shorten-the-boot-time>

Строение target'ов и специальные юниты — `man 5 systemd.target`, `man 7 systemd.special`,
`man 7 bootup`; всё проверено на стенде.

---

## Предварительные требования

Части 1, 3 и 4 выполняются по SSH. Части 2.2 (`rescue`) и 2.3 (`emergency`), а также оба
инцидента из части 5 **уводят систему туда, где нет SSH** — их делают только при открытой
консоли, которую открывает ментор. Если запустить `systemctl rescue`/`emergency` по SSH,
сессия оборвётся и вернуть систему будет нечем.

```bash
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

rpm -q systemd
# systemd-257-23.el10_2.2.x86_64
```

Готовность стенда проверяет `sudo ./verify/prepare.sh`.

---

## Стартовая проверка

```bash
sudo ./run.sh | sed -n '/Текущее состояние/,/Активные target/p'
# === Текущее состояние ===
# is-system-running:  running
# target по умолчанию: multi-user.target
# default.target ->    /usr/lib/systemd/system/multi-user.target
# runlevel:            run-level 3  2026-10-10 13:37
# [OK] target по умолчанию multi-user.target, как в исходном образе
```

`./run.sh` целиком показывает текущий target, список активных target'ов, флаги
`AllowIsolate`, наличие `systemd.unit=` в загрузке, время загрузки и упавшие юниты.

---

## Часть 1: Что такое target

### Теория для изучения перед частью

- Target — это юнит-«цель» (`man 5 systemd.target`). Он сам ничего не делает, а через
  `Requires=`/`Wants=` тянет набор других юнитов. Загрузка системы — это достижение
  одного target'а (`default.target`), который зависит от более ранних.
- Target пришёл на смену runlevel'ам SysV. Соответствие задано символическими ссылками:
  `runlevel3.target → multi-user.target`, `runlevel5.target → graphical.target`,
  `runlevel1.target → rescue.target`. `who -r` и `runlevel` всё ещё показывают число, но
  работают именно target'ы (`man 7 bootup`).
- Ключевые target'ы: `multi-user.target` (текстовая многопользовательская система, сеть,
  службы — то, что нужно серверу), `graphical.target` (то же плюс графический вход),
  `rescue.target` и `emergency.target` (аварийные режимы, часть 2), `reboot.target` /
  `poweroff.target` (перезагрузка/выключение — это тоже target'ы).
- Источники: `man 5 systemd.target`, `man 7 systemd.special`, `man 7 bootup`.

### 1.1 Какие target есть и какой активен

```bash
systemctl get-default
# multi-user.target

systemctl list-units --type target
#   UNIT                     LOAD   ACTIVE SUB    DESCRIPTION
#   basic.target             loaded active active Basic System
#   getty.target             loaded active active Login Prompts
#   multi-user.target        loaded active active Multi-User System
#   network-online.target    loaded active active Network is Online
#   ...
#   sysinit.target           loaded active active System Initialization
# 24 loaded units listed. Pass --all to see loaded but inactive units, too.
```

Активны сразу несколько target'ов: `multi-user.target` и всё, от чего он зависит
(`basic.target`, `sysinit.target`, `network.target`…). Это и есть отличие от runlevel'а,
где режим был один. Соответствие со старыми номерами:

```bash
ls -l /usr/lib/systemd/system/runlevel*.target
# runlevel0.target -> poweroff.target
# runlevel1.target -> rescue.target
# runlevel3.target -> multi-user.target
# runlevel5.target -> graphical.target
# runlevel6.target -> reboot.target

who -r
#          run-level 3  2026-10-05 11:00
```

### 1.2 Из чего состоит target

```bash
systemctl cat multi-user.target
# [Unit]
# Description=Multi-User System
# Documentation=man:systemd.special(7)
# Requires=basic.target
# Conflicts=rescue.service rescue.target
# After=basic.target rescue.service rescue.target
# AllowIsolate=yes
```

`Requires=basic.target` — multi-user тянет базовую систему. `AllowIsolate=yes` — в этот
target можно переключиться командой `isolate` (часть 2). `Conflicts=rescue.target` —
rescue и multi-user взаимно исключаются. У `graphical.target` в начале стоит
`Requires=multi-user.target` — поэтому graphical включает в себя всё из multi-user
(в том числе `sshd`). Что именно тянет target, видно так:

```bash
systemctl list-dependencies multi-user.target | head
# multi-user.target
# ● ├─auditd.service
# ● ├─chronyd.service
# ● ├─crond.service
# ● ├─NetworkManager.service
# ● ├─sshd.service
# ...
```

---

## Часть 2: Переключить target на работающей системе

### Теория для изучения перед частью

- `systemctl isolate <target>` переключает **работающую** систему в указанный target:
  запускает его и всё, что он тянет, и останавливает всё, что в новый target не входит
  (документация RHEL 10, 3.3). Это действует только на текущую сессию: после
  перезагрузки система снова придёт в target по умолчанию.
- Isolate разрешён не для всех target'ов, а только для тех, у кого `AllowIsolate=yes`.
  У `basic.target`, `sysinit.target` он `no` — в них переключиться нельзя.
- `rescue.target` и `emergency.target` — аварийные режимы. Оба дают оболочку через
  `sulogin`, который спрашивает пароль **root установленной системы**. Этим они
  отличаются от `rd.break` (лаба 04): тот спрашивает пароль initramfs. На стенде root
  заблокирован, поэтому `sulogin` оболочку не даёт — это видно ниже.
- `systemctl rescue` похоже на `isolate rescue.target`, но дополнительно рассылает
  предупреждение всем, кто в системе (3.4). `--no-wall` его подавляет.
- Источники: RHEL 10, «Using systemd unit files…», разделы 3.3–3.5; `man 1 systemctl`.

### 2.1 isolate: сменить target на лету

Это безопасно по SSH: `graphical.target` требует `multi-user.target`, поэтому `sshd` и
сеть остаются.

```bash
systemctl is-active multi-user.target graphical.target
# active
# inactive

systemctl isolate graphical.target
systemctl is-active multi-user.target graphical.target
# active
# active

who -r
#          run-level 5  2026-10-05 12:57                   last=3

systemctl is-active sshd.service NetworkManager.service
# active
# active
```

Вернуться в target по умолчанию:

```bash
systemctl isolate default.target
systemctl is-active graphical.target
# inactive
who -r
#          run-level 3  2026-10-05 12:57                   last=5
```

Не всякий target допускает isolate:

```bash
systemctl show -p AllowIsolate --value basic.target
# no

systemctl isolate basic.target
# Failed to start basic.target: Operation refused, unit may not be isolated.
# See system logs and 'systemctl status basic.target' for details.
```

### 2.2 rescue — только с консоли

> ⚠ Делайте это на стенде **только при открытой консоли**. `rescue` останавливает сеть
> и `sshd`; по SSH вы потеряете связь.

```bash
systemctl rescue
```

В rescue поднят минимум: локальные ФС смонтированы, но сети нет.

```bash
systemctl is-active rescue.target multi-user.target
# active
# inactive

systemctl is-active sshd.service NetworkManager.service
# inactive
# inactive

who -r
#          run-level 1  2026-10-05 13:04                   last=3

ss -tln
# State Recv-Q Send-Q Local Address:Port Peer Address:Port
# (пусто — никто не слушает, SSH недоступен)
```

На стенде root заблокирован, поэтому аварийная оболочка не открывается:

```text
You are in rescue mode. After logging in, type "journalctl -xb" to view
system logs, "systemctl reboot" to reboot, or "exit" to continue bootup.
Cannot open access to console, the root account is locked.
Press Enter to continue.
```

Это прямая связь с лабой 04: rescue/emergency упираются в пароль root, а `rd.break` —
нет. Вернуться из rescue (когда оболочка доступна): `systemctl default`.

### 2.3 emergency — только с консоли

`emergency.target` ещё «раньше» rescue: не монтирует лишние ФС и не поднимает сеть.
Задают его обычно разово из меню GRUB — `systemd.unit=emergency.target` (часть 3.2).
Команда `systemctl emergency` по SSH обрывает соединение сразу:

```bash
systemctl emergency
# Connection to 51.21.223.155 closed by remote host.

# новый вход уже не проходит:
ssh ec2-user@51.21.223.155
# ssh: connect to host 51.21.223.155 port 22: Connection refused
```

Поэтому `emergency` отрабатывают только с консоли.

---

## Часть 3: target по умолчанию и разовый выбор

### Теория для изучения перед частью

- `systemctl set-default <target>` задаёт target, в который система загружается **по
  умолчанию**. Технически это символическая ссылка `/etc/systemd/system/default.target`.
  Она переживает перезагрузку — в этом смысл «configurations must persist after reboot».
- `set-default` не меняет текущий режим — только следующую загрузку. Чтобы переключиться
  сразу, есть `systemctl isolate default.target` (часть 2).
- Разовый выбор target на одну загрузку — параметр ядра `systemd.unit=<target>`,
  дописанный в меню GRUB (документация RHEL 10, 3.5). Это тот же приём разовой правки,
  что в лабе 04 с `rd.break`.
- `systemd.unit=` в командной строке ядра **перекрывает** `default.target`. Если его
  прописать в запись постоянно (через `grubby`), получится ловушка из инцидента 2.
- Источники: RHEL 10, «Using systemd unit files…», разделы 3.2 и 3.5.

### 3.1 Постоянный target: set-default

```bash
systemctl get-default
# multi-user.target

ls -l /etc/systemd/system/default.target
# ... /etc/systemd/system/default.target -> /usr/lib/systemd/system/multi-user.target

systemctl set-default graphical.target
# Removed '/etc/systemd/system/default.target'.
# Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/graphical.target'.

systemctl get-default
# graphical.target
```

`set-default` не изменил текущий режим — только задал следующий. Проверяем перезагрузкой
(на стенде — с ведома ментора):

```bash
systemctl reboot
# --- после перезагрузки
systemctl get-default
# graphical.target
systemctl is-active graphical.target
# active
```

Имя target проверяется — ошибку не пропустит:

```bash
systemctl set-default multiuser.target
# Failed to set default target: Unit multiuser.target does not exist

systemctl set-default sshd.service
# Failed to set default target: Invalid argument
```

Вернуть по умолчанию multi-user:

```bash
systemctl set-default multi-user.target
# Removed '/etc/systemd/system/default.target'.
# Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/multi-user.target'.
```

### 3.2 Разовый target: systemd.unit в командной строке ядра

Разовый выбор — в меню GRUB: `e`, в конец строки `linux` дописать
`systemd.unit=graphical.target`, `Ctrl+x` (как `rd.break` в лабе 04). Постоянный вариант
— `grubby` из лабы 01; на нём хорошо видно, как `systemd.unit=` перекрывает умолчание:

```bash
grubby --update-kernel=DEFAULT --args=systemd.unit=graphical.target
grubby --info=DEFAULT | grep ^args
# args="... crashkernel=2G-64G:256M,64G-:512M $tuned_params systemd.unit=graphical.target"

systemctl reboot
# --- после перезагрузки
systemctl get-default
# Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
# multi-user.target

systemctl is-active graphical.target
# active
```

`get-default` честно печатает значение симлинка (`multi-user.target`) и при этом
предупреждает: `systemd.unit` на командной строке ядра перекрывает умолчание, а
загрузились мы в graphical. Запомните это предупреждение — на нём построен инцидент 2.
Убрать параметр:

```bash
grubby --update-kernel=DEFAULT --remove-args=systemd.unit
systemctl reboot
```

---

## Часть 4: Анализ загрузки (systemd-analyze)

### Теория для изучения перед частью

- `systemd-analyze` читает данные **последней успешной загрузки** и показывает, сколько
  она заняла (документация RHEL 10, 5.1). Это не цель экзамена, а инструмент: с него
  начинают, когда система грузится медленно.
- `systemd-analyze blame` — список юнитов по убыванию времени инициализации.
- `systemd-analyze critical-chain` — цепочка зависимостей, определившая момент выхода в
  target. Красный текст — юниты, критически замедляющие загрузку.
- Важно не путать `blame` с общим временем: времена юнитов идут параллельно, их сумма
  бессмысленна. «Правду» о задержке говорит `critical-chain`.
- Источники: RHEL 10, «Using systemd unit files…», 5.1; `man 1 systemd-analyze`.

### 4.1 Общее время по фазам

```bash
systemd-analyze
# Startup finished in 6.894s (kernel) + 7.647s (initrd) + 18.781s (userspace) = 33.323s
# multi-user.target reached after 17.128s in userspace.
```

Три фазы: ядро, initramfs, пользовательское пространство. `multi-user.target reached
after …` — когда система стала готова к работе.

### 4.2 blame: кто дольше поднимался

```bash
systemd-analyze blame | head
# 13.073s sys-module-configfs.device
# 13.072s dev-ttyS2.device
# 13.071s dev-ttyS0.device
# 12.508s dev-nvme0n1.device
# ...
```

Наверху — `*.device`-юниты. Их «время» — это ожидание, пока устройство появится (serial-
порты, диски EBS), а не работа службы. Такие ожидания идут параллельно, поэтому их нельзя
складывать и они не равны общему времени из `systemd-analyze`.

### 4.3 critical-chain: что держало загрузку

```bash
systemd-analyze critical-chain
# multi-user.target @17.128s
# └─getty.target @17.096s
#   └─serial-getty@ttyS0.service @17.059s
#     └─systemd-user-sessions.service @16.294s +410ms
#       └─cloud-init.service @14.903s +675ms
#         └─NetworkManager-wait-online.service @14.076s +783ms
#           └─NetworkManager.service @13.753s +214ms
#             └─network-pre.target @13.713s
#               └─cloud-init-local.service @10.969s +2.701s
#                 └─...
```

После `@` — момент, когда юнит стал активен; после `+` — сколько он сам поднимался. Видно,
что цепочку держат `cloud-init-local.service` (+2.701s) и
`NetworkManager-wait-online.service` (+783ms) — ожидание сети при загрузке облачной ВМ.
Именно это, а не `*.device` из `blame`, определило время выхода в target.

---

## Часть 5: Troubleshooting

> ⚠ Оба инцидента после перезагрузки уводят систему в rescue без SSH. Воспроизводите их
> (`make-broken.sh --apply`) только при открытой консоли и с ментором.

### Теория: диагностика по симптому

- «После перезагрузки нет SSH, с консоли — rescue» — почти всегда target по умолчанию или
  `systemd.unit=` в загрузке. Первая команда — `systemctl get-default`.
- Если `get-default` показывает `rescue.target` — поменяли умолчание (инцидент 1).
- Если `get-default` показывает `multi-user.target`, а всё равно rescue — смотрите
  `/proc/cmdline`: там `systemd.unit=` (инцидент 2).

### Инцидент 1: машина ушла в rescue и не пускает по SSH

Разбор и воспроизведение — `broken/scenario-01/`. Симптом: после перезагрузки SSH
отвечает `Connection refused`, с консоли система в rescue. Причина — `systemctl
set-default rescue.target` вместо разовой правки. Диагностика — `systemctl get-default`
(= `rescue.target`). Решение — `systemctl set-default multi-user.target` и перезагрузка;
разбор в `solutions/01-default-target/`.

### Инцидент 2: get-default говорит multi-user, а грузится rescue

Разбор — `broken/scenario-02/`. Симптом тот же (rescue, нет SSH), но `systemctl
get-default` показывает `multi-user.target` и строку `Note: found "systemd.unit" …`.
Причина — `systemd.unit=rescue.target`, дописанный во все записи через `grubby --args`.
Диагностика — `/proc/cmdline` и `grubby --info=ALL`. Решение — `grubby
--update-kernel=ALL --remove-args="systemd.unit"` и перезагрузка; разбор в
`solutions/02-remove-systemd-unit/`.

---

## Как подготовлен стенд

Специальной подготовки модуль почти не требует: target'ы, `systemctl` и `systemd-analyze`
есть в любой системе RHEL 10. Нужны только две вещи:

- **Консоль** для частей 2.2–2.3 и инцидентов — та же EC2 Serial Console и настройка меню
  GRUB, что в лабе 04 (раздел «Как подготовлен стенд» там). Без неё rescue/emergency не
  восстановить. `prepare.sh` откажется готовить стенд, если ядро не пишет в
  последовательный порт.
- **Исходное состояние**: target по умолчанию `multi-user.target`, в записях нет
  `systemd.unit=`. `prepare.sh` это проверяет и снимает снимок в
  `/var/lib/rhel-labs/05-systemd-targets/baseline.txt`.

На стенде root заблокирован (как в лабе 04) — поэтому rescue/emergency показывают
`Cannot open access to console, the root account is locked`. Это ожидаемо и само по себе
часть урока.

---

## Проверка модуля

Все пути даны от каталога модуля.

```bash
sudo ./run.sh                 # сводка: текущий target, isolate, systemd.unit=, время загрузки, failed-юниты
sudo ./scripts/qa/run-module.sh 05-systemd-targets   # prepare → verify → cleanup (из корня rhel-labs)
```

`verify.sh` проверяет, что стенд в исходном и рабочем состоянии: ядро пишет в
последовательный порт (иначе rescue из лабы не вернуть), нужные target'ы загружены и
допускают isolate, target по умолчанию `multi-user.target`, в записях и в текущей
загрузке нет `systemd.unit=`, система в `multi-user.target` (не в rescue) и
`systemd-analyze` читает прошлую загрузку.

```text
[OK] ядро пишет в последовательный порт (ttyS0): rescue/emergency из лабы восстановимы с консоли
[OK] target загружены: multi-user.target graphical.target rescue.target emergency.target poweroff.target reboot.target
[OK] multi-user/graphical/rescue/emergency допускают isolate (AllowIsolate=yes)
[OK] target по умолчанию multi-user.target и симлинк default.target ведёт туда же
[OK] в записях загрузчика нет systemd.unit=
[OK] текущая загрузка прошла без разового systemd.unit=
[OK] система в multi-user.target, не в rescue/emergency
[OK] systemd-analyze читает прошлую загрузку: Startup finished in 6.894s (kernel) + 7.647s (initrd) + 18.781s (userspace) = 33.323s
     дольше всех: 13.073s sys-module-configfs.device
[OK] is-system-running: running
[OK] module 05-systemd-targets verified
```

---

## Теоретические вопросы (итоговые)

1. Чем target отличается от прежнего runlevel и как они связаны?
2. В чём разница между `systemctl isolate <t>` и `systemctl set-default <t>`?
3. Почему `systemctl isolate basic.target` не выполняется, а `isolate graphical.target` —
   да?
4. Чем `rescue.target` отличается от `emergency.target` и почему оба на стенде не дают
   оболочку?
5. Что сильнее — `systemd.unit=` в командной строке ядра или `set-default`, и как это
   увидеть?
6. Почему в `systemd-analyze blame` наверху `*.device`-юниты и почему их времена не
   складываются в общее?

Ответы — в `ANSWERS.md`.

---

## Практические задания (отработка)

Задания в формате экзамена — в `tasks/`:

- `tasks/01-isolate-target.md` — переключить работающую систему в другой target и обратно.
- `tasks/02-default-target.md` — задать target по умолчанию и проверить перезагрузкой.
- `tasks/03-analyze-boot.md` — разобрать время загрузки через `systemd-analyze`.

---

## Шпаргалка

```text
# посмотреть
systemctl get-default                       # target по умолчанию
systemctl list-units --type target          # активные target'ы
systemctl cat multi-user.target             # из чего состоит target
systemctl show -p AllowIsolate --value <t>  # можно ли isolate

# переключить сейчас (на сессию)
systemctl isolate graphical.target
systemctl isolate default.target            # вернуться к умолчанию
systemctl rescue        # аварийный режим — ТОЛЬКО с консоли
systemctl emergency     # ещё раньше rescue — ТОЛЬКО с консоли

# задать по умолчанию (постоянно)
systemctl set-default multi-user.target

# разово на одну загрузку (меню GRUB: e -> строка linux -> Ctrl+e)
systemd.unit=rescue.target

# анализ загрузки
systemd-analyze
systemd-analyze blame | head
systemd-analyze critical-chain

# убрать systemd.unit=, случайно оставленный в записях
grubby --update-kernel=ALL --remove-args="systemd.unit"
```

---

## Чему вы научились

- Понимать target'ы: что это, как они связаны с runlevel'ами и из чего состоят
  (`Requires`, `Conflicts`, `AllowIsolate`).
- Переключать работающую систему между target'ами через `systemctl isolate` и знать, где
  это нельзя (`AllowIsolate=no`).
- Отличать rescue от emergency и понимать, почему они требуют пароль root, а `rd.break` —
  нет; почему эти режимы отрабатывают только с консоли.
- Задавать target по умолчанию через `set-default` (симлинк, переживающий перезагрузку) и
  выбирать target разово через `systemd.unit=` в меню GRUB.
- Видеть, что `systemd.unit=` на командной строке ядра перекрывает `default.target`, и
  диагностировать это по `/proc/cmdline`.
- Читать `systemd-analyze`, `blame` и `critical-chain` и не путать время отдельных юнитов
  с общим временем загрузки.

---

## Уборка

После занятия:

```bash
sudo ./verify/cleanup.sh           # убирает systemd.unit= из записей, возвращает target по умолчанию; ничего не удаляет
sudo systemctl reboot              # если в ходе занятия меняли target или cmdline
```

`cleanup.sh` без ключей убирает из записей `systemd.unit=`, если он там остался, и
возвращает target по умолчанию на `multi-user.target`. Если система осталась в rescue —
вернуть `systemctl default` или перезагрузкой. Настройку консоли/GRUB (из лабы 04)
`cleanup.sh` не трогает — это подготовка стенда.
