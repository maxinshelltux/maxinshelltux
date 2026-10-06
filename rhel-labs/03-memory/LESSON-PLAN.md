# План занятия 03: память — адресное пространство, выделение, нехватка, swap

Документ для ментора. Материал для ученика — `README.md`, задания — `tasks/`,
ответы — `ANSWERS.md`.

## Рамка

| | |
|---|---|
| Цели экзамена | EX200 (RHEL 10): **Identify CPU/memory intensive processes and kill processes**; **Add new partitions and logical volumes, and swap to a system non-destructively**; **Locate and interpret system log files and journals** |
| Сопутствующие цели | List, create, and delete partitions on GPT disks; Configure systems to mount file systems at boot by universally unique ID (UUID) or label; Start and stop services and configure services to start automatically at boot; Boot, reboot, and shut down a system normally |
| Не цель экзамена | адресное пространство, запрос и выдача памяти, overcommit, пределы cgroup — фон в частях 1–3 и 5.1 |
| Длительность | 110 минут; при нехватке времени части 1–3 даются короче, части 4–6 — полностью |
| Стенд | `rhel10-lab`, RHEL 10.2, 1647 МиБ памяти, два пустых диска по 5 ГиБ; вход `ec2-user`, root через `sudo -i` |
| Результат | ученик выполняет три задания из `tasks/`; swap доказан на перезагруженной системе |

Сквозная мысль: числа про память обманчивы, пока не знаешь, что за ними. `free` —
не «сколько осталось», VSZ — не «сколько занял», а запрос памяти — не её выдача.

## Перед занятием

```bash
ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip>   # ментор
cd ~/rhel-labs && sudo ./scripts/qa/run-module.sh 03-memory
sudo ./03-memory/run.sh | tail -n 2
systemctl is-system-running
```

Проверка модуля должна закончиться строкой `[OK] module 03-memory verified`,
состояние системы — `running`. Если раздел `labswap` уже есть (остался с прошлого
занятия), ученик в части 6 его не создаст: удалить раздел может только человек —
`sudo ./03-memory/verify/cleanup.sh --apply`.

## Ход занятия

| Время | Блок | Что делает ученик | На что смотреть |
|---|---|---|---|
| 0–5 | Вход | Читает таблицу целей: что экзамен, что фон | Понимает ли, зачем фон |
| 5–20 | Часть 1 | `free`, `/proc/meminfo`, опыт с кешем | Называет ли `available`, а не `free` |
| 20–35 | Часть 2 | `maps`, `ps`, `status`, `pmap` живого процесса | Находит ли свою область в 200 МиБ |
| 35–50 | Часть 3 | `memhog.py` без записи и с записью, overcommit | Предсказывает ли, что вырастет |
| 50–65 | Часть 4 | Находит и завершает процесс, видит след SIGKILL | Начинает ли с SIGTERM |
| 65–75 | Часть 5 | Предел группы, код 137, журнал ядра | Читает ли `constraint` и `anon-rss` |
| 75–100 | Часть 6 | Раздел, `mkswap`, `fstab`, перезагрузка | Проверяет ли строку до перезагрузки |
| 100–110 | Часть 7 и итог | Инцидент 1, итоговые вопросы | Смотрит ли на PPID и юнит |

## Опорные вопросы по ходу

Задавайте до того, как ученик выполнит команду.

1. Перед 1.2: «`free` показывает 863 МиБ. Получит ли процесс 900?»
2. Перед 3.1: «Программа попросила 300 МиБ. На сколько уменьшится `available`?»
3. Перед 3.3: «Памяти 1647 МиБ, доступно 1230. Пройдёт ли запрос на 1600?»
4. Перед 4.3: «Чем для службы отличается смерть от SIGTERM и от SIGKILL?»
5. Перед 5.1: «Лимит 200 МиБ, запрос 400. В какой момент процесс погибнет?»
6. Перед 6.3: «Swap работает. Что будет после перезагрузки?»

## Типичные ошибки

| Ошибка | Как проявляется | Что показать |
|---|---|---|
| Судит о памяти по колонке `free` | «память кончилась», хотя это кеш | опыт 1.2 |
| Ищет виновника по VSZ | находит не того | три процесса из 3.3 |
| Сразу `kill -9` | служба в `failed`, система `degraded` | 4.3 |
| Убивает процесс службы снова и снова | новый PID каждые две секунды | `broken/scenario-01` |
| `swapon` без строки в `fstab` | swap пропал после перезагрузки | `broken/scenario-02` |
| Пишет в `fstab` имя устройства | на этом стенде имена `nvme` меняются | 6.1, ответ про UUID |
| Не проверяет строку перед перезагрузкой | `swapon: cannot open UUID=` | 6.3: `findmnt --verify`, `swapon -a` |
| Берёт UUID сразу после `mkswap` через `lsblk` | пустая строка | `udevadm settle` или `blkid` |

## Чего на стенде делать нельзя

- Не доводить до нехватки памяти всю систему: все опыты с OOM идут под
  `MemoryMax`. Глобальный OOM может убить что угодно, а консоли у стенда нет.
- Не включать `vm.overcommit_memory=2`: на 1,6 ГиБ это может не дать запуститься
  новым процессам, включая SSH.
- Не трогать системный диск (тот, где `/`); перед `parted` сверяться с `lsblk`.
- Не оставлять в `/etc/fstab` строку, не проверенную `swapon -a`.
- Не запускать опыт 6.5 (`MemoryMax` без запрета swap) без включённого swap и не
  заменять в нём `MemoryMax` на `MemoryHigh`: при подготовке процесс с
  `MemoryHigh=100M` без swap завис, его пришлось останавливать вручную.

## Критерии «тема усвоена»

- Объясняет `available`, VSZ и RSS своими словами и показывает их в выводе.
- Находит виновника по RSS и завершает его; узнаёт процесс службы и идёт в
  `systemctl`.
- По записи `oom-kill` в журнале называет причину, группу и объём памяти.
- Добавляет swap на новом разделе, прописывает по UUID, проверяет до и после
  перезагрузки — без подсказок.
- Выполняет три задания из `tasks/` примерно за 25 минут суммарно.

## Домашнее задание

1. Повторить `tasks/01`–`03` с нуля, без README, засекая время.
2. Разобрать `broken/scenario-02` (на занятии разбирали первый инцидент).
3. Прочитать разделы 13.1–13.4 руководства RHEL 10 «Managing storage devices» и
   сравнить порядок действий с частью 6.

## После занятия

```bash
sudo ./03-memory/verify/cleanup.sh          # останавливает процессы, отключает swap, чистит fstab
sudo ./03-memory/verify/cleanup.sh --apply  # удаляет раздел labswap; запускает человек
systemctl is-system-running
```

## Источники

- Цели экзамена EX200:
  <https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam>
- RHEL 10, «Managing storage devices», глава 13 «Getting started with swap»
  (разделы 13.1, 13.3, 13.4):
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_storage_devices/getting-started-with-swap>
- Там же, глава 4 «Getting started with partitions» (разделы 4.1–4.3):
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_storage_devices/getting-started-with-partitions>
- Документация ядра, «Overcommit Accounting»:
  <https://docs.kernel.org/mm/overcommit-accounting.html>
- `man free`, `man vmstat`, `man ps`, `man top`, `man pmap`, `man kill`, `man pkill`,
  `man systemd-run`, `man systemd.resource-control`, `man swapon`, `man mkswap`,
  `man parted` на стенде.
