# Лабораторная работа 06: udev и постоянные имена устройств

## Оглавление
<!-- TOC -->
- [Соответствие целям экзамена RHCSA](#соответствие-целям-экзамена-rhcsa)
- [Откуда взяты команды](#откуда-взяты-команды)
- [Предварительные требования](#предварительные-требования)
- [Стартовая проверка](#стартовая-проверка)
- [Часть 1: Почему имена устройств «плавают»](#часть-1-почему-имена-устройств-плавают)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью)
  - [1.1 Имена ядра меняются между загрузками](#11-имена-ядра-меняются-между-загрузками)
  - [1.2 Постоянные имена в /dev/disk](#12-постоянные-имена-в-devdisk)
- [Часть 2: Монтирование по UUID и label](#часть-2-монтирование-по-uuid-и-label)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-1)
  - [2.1 Найти UUID и label](#21-найти-uuid-и-label)
  - [2.2 Запись в fstab по UUID](#22-запись-в-fstab-по-uuid)
- [Часть 3: udev — откуда берутся имена](#часть-3-udev--откуда-берутся-имена)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-2)
  - [3.1 udevadm info: свойства и симлинки устройства](#31-udevadm-info-свойства-и-симлинки-устройства)
  - [3.2 udevadm monitor, trigger, settle](#32-udevadm-monitor-trigger-settle)
  - [3.3 Где лежат правила udev](#33-где-лежат-правила-udev)
- [Часть 4: Своё правило — стабильный симлинк](#часть-4-своё-правило--стабильный-симлинк)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-3)
  - [4.1 Написать и применить правило](#41-написать-и-применить-правило)
  - [4.2 Убрать правило](#42-убрать-правило)
- [Часть 5: Troubleshooting](#часть-5-troubleshooting)
  - [Теория: диагностика по симптому](#теория-диагностика-по-симптому)
  - [Инцидент 1: система не загрузилась после правки fstab](#инцидент-1-система-не-загрузилась-после-правки-fstab)
  - [Инцидент 2: правило udev не создаёт симлинк](#инцидент-2-правило-udev-не-создаёт-симлинк)
- [Как подготовлен стенд](#как-подготовлен-стенд)
- [Проверка модуля](#проверка-модуля)
- [Теоретические вопросы (итоговые)](#теоретические-вопросы-итоговые)
- [Практические задания (отработка)](#практические-задания-отработка)
- [Шпаргалка](#шпаргалка)
- [Чему вы научились](#чему-вы-научились)
- [Уборка](#уборка)
<!-- /TOC -->

> ⏱ время ~60 мин · сложность 3/5 · пререквизиты: лабы 01 и 03; для инцидента 1 — консоль стенда (её открывает ментор)

Цель: научиться опознавать устройства по устойчивым признакам и монтировать файловые
системы так, чтобы они переживали перезагрузку, — как того требует цель экзамена *Configure
systems to mount file systems at boot by UUID or label*. Попутно разбираемся, откуда
берутся имена в `/dev/disk/` и как ими управляет udev.

> Все «ожидаемые выводы» сняты 2026-10-10 на стенде `rhel10-lab`: RHEL 10.2, AWS
> `t3.small`, `systemd-udev-257`. Диски — три тома EBS (`nvme0n1`, `nvme1n1`, `nvme2n1`),
> один пустой запасной. У вас серийники, UUID и даже порядок имён `nvme` будут свои —
> важна **структура** вывода.

---

## Соответствие целям экзамена RHCSA

Формулировки целей приведены дословно со
[страницы экзамена EX200](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
(версия для Red Hat Enterprise Linux 10, сверено 2026-10-10).

| Что делаем в модуле | Цель EX200 (дословно) | Раздел целей |
|---|---|---|
| Находим UUID/label, монтируем ФС по UUID и закрепляем в fstab (части 1–2, задания 01–02) | Configure systems to mount file systems at boot by universally unique ID (UUID) or label | Configure local storage |
| Создаём и монтируем XFS на запасном диске (часть 2, задание 02) | Create, mount, unmount, and use VFAT, ext4, and XFS file systems | Create and configure file systems |
| `man 7 udev`, `man 8 udevadm`, `man 5 fstab`, раздел документации RHEL 10 | Locate, read, and use system documentation including man, info, and files in /usr/share/doc | Understand and use essential tools |

Что модуль **не** закрывает отдельной целью: правила udev (части 3–4) — не цель EX200, а
смежный материал из документации RHEL 10. Он здесь, чтобы понять, откуда берутся
постоянные имена, на которых держится цель про монтирование по UUID.

---

## Откуда взяты команды

Основной источник — документация RHEL 10 «Managing storage devices», глава 2 «Persistent
naming attributes»:

- раздел 2.1 «Persistent attributes for identifying file systems and block devices» —
  `by-id`, `by-path`, `by-uuid`, `by-label`, `by-partuuid`;
- раздел 2.2 «udev device naming rules» — где лежат правила udev и как получить симлинки
  устройства через `udevadm info`:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_storage_devices/persistent-naming-attributes>

Синтаксис правил udev этот раздел берёт из `man 7 udev` на стенде; команды `udevadm` — из
`man 8 udevadm`; запись fstab — `man 5 fstab`.

---

## Предварительные требования

Части 1–4 и инцидент 2 выполняются по SSH. Инцидент 1 (сбойный `/etc/fstab`) после
перезагрузки уводит систему в emergency — его делают только при открытой консоли (её
открывает ментор), иначе систему не вернуть.

```bash
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)

lsblk -dno NAME,SIZE,TYPE | grep disk
# nvme1n1 5G disk
# nvme0n1 5G disk
# nvme2n1 20G disk
```

На стенде есть пустой запасной диск (без ФС) — он нужен для заданий 02–03. Готовность
проверяет `sudo ./verify/prepare.sh`.

---

## Стартовая проверка

```bash
sudo ./run.sh | sed -n '/fstab: по чему/,/Запасной диск/p'
# === fstab: по чему монтируется ===
#   /         UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 xfs  defaults
#   /boot/efi UUID=97D2-64D3                            vfat defaults,uid=0,gid=0,umask=077,shortname=winnt
# [OK] fstab монтирует по UUID/LABEL, все идентификаторы разрешаются
```

`./run.sh` целиком показывает диски и их постоянные имена, каталоги `/dev/disk/*`, по чему
монтирует fstab, запасной диск и учебные правила udev.

---

## Часть 1: Почему имена устройств «плавают»

### Теория для изучения перед частью

- Имя ядра (`/dev/sda`, `/dev/nvme0n1`) присваивается в порядке обнаружения устройств при
  загрузке. Этот порядок не гарантирован: на стенде имена `nvme` перетасовываются между
  загрузками (вы это видели в `02-kernel-modules` и `03-memory`).
- Чтобы ссылаться на устройство устойчиво, udev создаёт в `/dev/disk/` символические
  ссылки, построенные из неизменных признаков (UUID, метка, серийный номер, слот PCI).
- Правило простое: в конфигурации (fstab, скрипты) имя ядра не используют — только
  постоянные идентификаторы.
- Источник: RHEL 10, «Managing storage devices», раздел 2.1.

### 1.1 Имена ядра меняются между загрузками

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,SERIAL
# NAME         SIZE TYPE FSTYPE LABEL UUID                                 SERIAL
# nvme1n1        5G disk                                             vol0ed094b9462cbadc2
# nvme0n1        5G disk                                             vol026abf1eaef5fbb15
# └─nvme0n1p1    1G part swap               53a00af0-b460-4ed0-a2a0-4ec3b686ee94
# nvme2n1       20G disk
# ├─nvme2n1p1    1M part
# ├─nvme2n1p2  200M part vfat   ESP   97D2-64D3
# └─nvme2n1p3 19.8G part xfs    root  c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1

findmnt -no SOURCE /
# /dev/nvme2n1p3
```

Обратите внимание: корень сейчас на `nvme2n1`, хотя дисков три и диск с системой не
обязан быть «нулевым». При другой загрузке номера `nvme` могут встать иначе. Серийный
номер (`SERIAL`, столбец EBS-тома `vol…`) к диску, наоборот, привязан.

### 1.2 Постоянные имена в /dev/disk

```bash
ls /dev/disk/
# by-diskseq  by-id  by-label  by-partlabel  by-partuuid  by-path  by-uuid

ls -l /dev/disk/by-uuid/
# c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 -> ../../nvme2n1p3
# 97D2-64D3                            -> ../../nvme2n1p2
# 53a00af0-b460-4ed0-a2a0-4ec3b686ee94 -> ../../nvme0n1p1

ls -l /dev/disk/by-id/ | grep vol0ed094b9462cbadc2
# nvme-Amazon_Elastic_Block_Store_vol0ed094b9462cbadc2 -> ../../nvme1n1
```

- `by-uuid` — по UUID файловой системы;
- `by-label` — по метке ФС (здесь у корня метка `root`, у ESP — `ESP`);
- `by-id` — по вендору/модели/серийнику (для диска целиком, даже без ФС);
- `by-path` — по слоту PCI;
- `by-partuuid`/`by-partlabel` — по разделу из таблицы GPT.

Для монтирования ФС берут `by-uuid`/`by-label`. Для диска целиком, когда ФС ещё нет
(запасной `nvme1n1`), устойчивы только `by-id` и `by-path`.

---

## Часть 2: Монтирование по UUID и label

### Теория для изучения перед частью

- UUID записан в самой файловой системе и не меняется при перезагрузке и перетасовке
  имён. Метка (`LABEL`) — заданное человеком имя ФС. И то, и другое подходит для fstab.
- В `/etc/fstab` источник пишут как `UUID=<uuid>` или `LABEL=<метка>`, а не `/dev/имя`.
- Опция `nofail` делает запись необязательной для загрузки: если ФС не смонтировалась,
  система всё равно загрузится, а не уйдёт в emergency. Для некорневых учебных ФС это
  разумно.
- Новую запись fstab проверяют **до** перезагрузки: `findmnt --verify` и `mount -a`.
- Источник: RHEL 10, «Managing storage devices», 2.1; `man 5 fstab`, `man 8 mount`.

### 2.1 Найти UUID и label

```bash
sudo blkid
# /dev/nvme2n1p3: LABEL="root" UUID="c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1" TYPE="xfs" PARTUUID="31d7332c-..."
# /dev/nvme0n1p1: UUID="53a00af0-b460-4ed0-a2a0-4ec3b686ee94" TYPE="swap" PARTLABEL="labswap"
# /dev/nvme2n1p2: LABEL="ESP" UUID="97D2-64D3" TYPE="vfat"

sudo blkid -s UUID -o value /dev/nvme2n1p3
# c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1
```

`blkid` показывает UUID, метку и тип каждой ФС. `-s UUID -o value` достаёт только UUID —
удобно подставлять в команды и fstab.

### 2.2 Запись в fstab по UUID

На стенде fstab уже образцовый — всё по UUID:

```bash
findmnt --fstab --noheadings
# /         UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 xfs  defaults
# /boot/efi UUID=97D2-64D3                            vfat defaults,uid=0,gid=0,umask=077,shortname=winnt
```

Так монтируют и новую ФС (задание 02): создать ФС на запасном диске, взять её UUID и
добавить строку. Формат записи — `man 5 fstab`:

```text
UUID=<uuid>  /mnt/labdata  xfs  defaults,nofail  0 0
```

Проверка без перезагрузки:

```bash
findmnt --verify        # разбирает fstab, сообщает о недостижимых источниках
sudo mount -a           # домонтировать всё из fstab
findmnt /mnt/labdata
```

---

## Часть 3: udev — откуда берутся имена

### Теория для изучения перед частью

- Симлинки в `/dev/disk/*` создаёт udev — менеджер устройств в пространстве пользователя
  (часть systemd). При появлении устройства udev обрабатывает правила и расставляет имена.
- Посмотреть всё, что udev знает об устройстве, и все его симлинки можно командой
  `udevadm info`.
- Правила хранятся в файлах `*.rules`. Два каталога: `/usr/lib/udev/rules.d/` — правила из
  пакетов (перезаписываются обновлениями), `/etc/udev/rules.d/` — для своих правил.
- После правки правил их надо перечитать (`udevadm control --reload`) и применить
  (`udevadm trigger`), дождавшись завершения (`udevadm settle`).
- Источники: RHEL 10, «Managing storage devices», 2.2; `man 8 udevadm`, `man 7 udev`.

### 3.1 udevadm info: свойства и симлинки устройства

```bash
sudo udevadm info --name /dev/nvme1n1 --query property --property DEVLINKS --value
# /dev/disk/by-path/pci-0000:00:1f.0-nvme-1 /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol0ed094b9462cbadc2 ...

sudo udevadm info --name /dev/nvme1n1 --query property | grep -E '^ID_(SERIAL|MODEL|PATH)'
# ID_SERIAL_SHORT=vol0ed094b9462cbadc2
# ID_SERIAL=Amazon_Elastic_Block_Store_vol0ed094b9462cbadc2_1
# ID_MODEL=Amazon Elastic Block Store
# ID_PATH=pci-0000:00:1f.0-nvme-1
```

`DEVLINKS` — это и есть все постоянные имена устройства (то, что видно в `/dev/disk/*`).
`ID_SERIAL_SHORT` — серийный номер; на нём удобно строить своё правило (часть 4). Обратите
внимание: `ID_SERIAL` и `ID_SERIAL_SHORT` — разные строки (это важно для инцидента 2).

### 3.2 udevadm monitor, trigger, settle

`udevadm monitor` показывает события устройств в реальном времени. Если в другом окне
(или через `trigger`) вызвать событие, оно появится:

```bash
sudo udevadm trigger --name-match=nvme1n1 --action=change
# UDEV  [85311.273274] change   /devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1 (block)
```

- `udevadm control --reload` — перечитать файлы правил;
- `udevadm trigger` — переотправить события устройствам, чтобы правила применились к уже
  существующим;
- `udevadm settle` — дождаться, пока обработка закончится.

### 3.3 Где лежат правила udev

```bash
ls /usr/lib/udev/rules.d/ | head -3     # правила из пакетов — НЕ трогаем
# 00-scsi-sg3_config.rules
# 01-md-raid-creating.rules
# 10-dm.rules

ls /etc/udev/rules.d/                    # сюда кладём своё
```

`man 7 udev` описывает синтаксис. Правило — это строка из ключей сопоставления (с `==`) и
присваивания (с `=`, `+=`). Ключевые ключи сопоставления:

```text
KERNEL==     имя устройства у ядра (nvme1n1)
SUBSYSTEM==  подсистема (block, net, …)
ATTR{...}==  значение атрибута в sysfs
ENV{...}==   свойство устройства (ID_SERIAL_SHORT и т.п.)
```

и присваивания: `SYMLINK+="имя"` (добавить симлинк в `/dev`), `OWNER=`, `GROUP=`, `MODE=`.

---

## Часть 4: Своё правило — стабильный симлинк

### Теория для изучения перед частью

- Задача: дать запасному диску имя `/dev/lab-spare`, которое указывает на него при любом
  имени ядра. Для этого правило сопоставляет по `ID_SERIAL_SHORT` (серийник привязан к
  диску) и добавляет симлинк через `SYMLINK+=`.
- Файл правила кладут в `/etc/udev/rules.d/` с расширением `.rules`; имя файла начинают с
  числа (порядок применения), например `99-lab-spare.rules`.
- Источник: RHEL 10, «Managing storage devices», 2.2; `man 7 udev`.

### 4.1 Написать и применить правило

```bash
# серийник запасного диска
SHORT=$(sudo udevadm info --name /dev/nvme1n1 --query property --property ID_SERIAL_SHORT --value)

printf '%s\n' "SUBSYSTEM==\"block\", ENV{ID_SERIAL_SHORT}==\"$SHORT\", SYMLINK+=\"lab-spare\"" \
  | sudo tee /etc/udev/rules.d/99-lab-spare.rules
# SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="vol0ed094b9462cbadc2", SYMLINK+="lab-spare"

sudo udevadm control --reload
sudo udevadm trigger --name-match=nvme1n1 --action=change
sudo udevadm settle

ls -l /dev/lab-spare
# lrwxrwxrwx. 1 root root 7 Oct 10 14:46 /dev/lab-spare -> nvme1n1

sudo udevadm info --name /dev/lab-spare --query property --property DEVLINKS --value
# ... /dev/lab-spare ...
```

`/dev/lab-spare` появился и указывает на запасной диск; теперь он входит в его список
симлинков. При другом имени ядра правило всё равно найдёт диск по серийнику.

### 4.2 Убрать правило

```bash
sudo rm /etc/udev/rules.d/99-lab-spare.rules
sudo udevadm control --reload
sudo udevadm trigger --name-match=nvme1n1 --action=change
sudo udevadm settle

ls -l /dev/lab-spare
# ls: cannot access '/dev/lab-spare': No such file or directory
```

---

## Часть 5: Troubleshooting

> ⚠ Инцидент 1 после перезагрузки уводит систему в emergency без SSH — воспроизводите его
> (`make-broken.sh --apply`) только при открытой консоли и с ментором. Инцидент 2 безопасен
> по SSH.

### Теория: диагностика по симптому

- «Система не загрузилась после правки fstab» — почти всегда монтирование по имени ядра
  или без `nofail`. Проверяют запись `findmnt --verify`, не дожидаясь перезагрузки.
- «Правило udev не даёт симлинк» — ошибка в правиле или забытый `reload`. Отлаживают
  `udevadm test`.

### Инцидент 1: система не загрузилась после правки fstab

Разбор и воспроизведение — `broken/scenario-01/`. Симптом: после перезагрузки нет SSH, с
консоли — emergency. Причина — в `/etc/fstab` строка с монтированием по имени ядра
(`/dev/nvme1n1`) без `nofail`. Диагностика — `findmnt --verify` и чтение fstab. Решение —
убрать строку (или переписать по UUID с `nofail`); разбор в
`solutions/01-fstab-persistent/`.

### Инцидент 2: правило udev не создаёт симлинк

Разбор — `broken/scenario-02/`. Симптом: правило написано, `reload`/`trigger` сделаны, а
`/dev/lab-spare` нет. Причина — перепутан ключ (`ENV{ID_SERIAL}` вместо
`ENV{ID_SERIAL_SHORT}`), условие не совпадает. Диагностика — `udevadm test
/sys/class/block/nvme1n1` и сверка свойств `udevadm info`. Решение — убрать сбойное
правило и написать верное; разбор в `solutions/02-fix-udev-rule/`.

---

## Как подготовлен стенд

Специальной подготовки модуль не требует: udev, `udevadm`, `blkid`, `lsblk` есть в любой
RHEL 10. Нужны две вещи:

- **Пустой запасной диск** — на стенде это второй том EBS 5 ГБ без файловой системы
  (`nvme1n1` при текущей загрузке). На нём отрабатывают задания 02–03; `prepare.sh`
  сообщает, какой диск нашёл.
- **Консоль** для инцидента 1 — та же EC2 Serial Console, что в лабах 04–05. Инцидент
  уводит систему в emergency, а root на стенде заблокирован, так что вернуть можно только
  с консоли через `rd.break`.

`prepare.sh` снимает снимок исходного состояния (диски, `blkid`, `fstab`,
`/dev/disk/by-id`) в `/var/lib/rhel-labs/06-udev-persistent-naming/baseline.txt`.

---

## Проверка модуля

Все пути даны от каталога модуля.

```bash
sudo ./run.sh                 # сводка: диски, /dev/disk/*, fstab, запасной диск, правила udev
sudo ./scripts/qa/run-module.sh 06-udev-persistent-naming   # prepare → verify → cleanup
```

`verify.sh` проверяет, что система опирается на постоянные имена и чиста перед занятием:
каталоги `/dev/disk/by-*` на месте, udev видит корень и его `by-uuid`, в `/etc/fstab` нет
монтирования по имени ядра и все UUID/LABEL разрешаются, не осталось учебных правил udev и
симлинков `/dev/lab-*`.

```text
[OK] каталоги постоянных имён на месте: /dev/disk/by-uuid /dev/disk/by-id /dev/disk/by-path
[OK] udevadm видит корень /dev/nvme2n1p3 и его by-uuid ссылку
[OK] в /etc/fstab нет монтирования по имени ядра — только UUID/LABEL/by-*
[OK] все UUID/LABEL из /etc/fstab разрешаются в реальные устройства
[OK] учебных правил udev (/etc/udev/rules.d/99-lab-*.rules) нет
[OK] учебных симлинков /dev/lab-* нет
[OK] module 06-udev-persistent-naming verified
```

---

## Теоретические вопросы (итоговые)

1. Почему `/dev/nvme1n1` нельзя использовать в `/etc/fstab`, а `UUID=`/`LABEL=` — можно?
2. Чем отличаются `by-uuid`, `by-label`, `by-id`, `by-path`, `by-partuuid`?
3. Кто создаёт имена в `/dev/disk/*` и где лежат правила (разница `/usr/lib` и `/etc`)?
4. Как узнать все постоянные имена устройства и его серийник одной командой?
5. Что делают `udevadm control --reload`, `udevadm trigger`, `udevadm settle`?
6. Чем `ID_SERIAL` отличается от `ID_SERIAL_SHORT` и почему это источник ошибок в правилах?

Ответы — в `ANSWERS.md`.

---

## Практические задания (отработка)

Задания в формате экзамена — в `tasks/`:

- `tasks/01-identify-device.md` — найти постоянные имена и серийник устройства.
- `tasks/02-mount-by-uuid.md` — создать ФС и смонтировать её по UUID с `nofail` в fstab.
- `tasks/03-udev-symlink.md` — дать устройству свой симлинк правилом udev.

---

## Шпаргалка

```text
# опознать устройство
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,SERIAL
sudo blkid                                   # UUID, LABEL, TYPE всех ФС
sudo blkid -s UUID -o value /dev/nvme2n1p3   # только UUID
ls -l /dev/disk/by-uuid /dev/disk/by-id

# смонтировать по UUID (fstab, man 5 fstab)
UUID=<uuid>  /mnt/labdata  xfs  defaults,nofail  0 0
findmnt --verify        # проверить запись БЕЗ перезагрузки
sudo mount -a

# udev
sudo udevadm info --name /dev/DEV --query property                    # все свойства
sudo udevadm info --name /dev/DEV --query property --property DEVLINKS --value
sudo udevadm test /sys/class/block/DEV                                # отладка правил

# своё правило: /etc/udev/rules.d/99-*.rules
SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="<серийник>", SYMLINK+="lab-spare"
sudo udevadm control --reload
sudo udevadm trigger --name-match=DEV --action=change
```

---

## Чему вы научились

- Понимать, почему имена ядра (`/dev/nvme*`) неустойчивы, и опознавать устройства по
  постоянным признакам в `/dev/disk/*`.
- Находить UUID и метку файловой системы (`blkid`, `lsblk`) и монтировать ФС по UUID в
  `/etc/fstab` с `nofail`, проверяя запись `findmnt --verify` до перезагрузки.
- Получать свойства и симлинки устройства через `udevadm info`.
- Понимать роль udev и команд `udevadm control --reload`, `trigger`, `settle`.
- Писать правило udev в `/etc/udev/rules.d/`, дающее устройству стабильный симлинк, и
  отлаживать несработавшее правило через `udevadm test`.

---

## Уборка

После занятия:

```bash
sudo ./verify/cleanup.sh           # убирает учебные правила udev и перечитывает их
# если делали задание 02 (создавали ФС и монтировали):
sudo umount /mnt/labdata
# убрать добавленную строку из /etc/fstab
sudo wipefs -a /dev/nvme1n1        # вернуть запасной диск пустым (проверьте имя!)
```

`cleanup.sh` без ключей удаляет файлы `/etc/udev/rules.d/99-lab-*.rules`, если они
остались, и перечитывает правила. Файл `/etc/fstab` он не трогает — если туда попала
запись по имени ядра, предупреждает и отсылает к `solutions/01-fstab-persistent`.
