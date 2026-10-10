# rhel-labs — практика к экзамену RHCSA (EX200, RHEL 10)

Лабораторные работы для подготовки к сертификации. Каждый модуль называет цели
экзамена EX200, на которые он работает, дословно, со ссылкой на
[страницу экзамена](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam).
Если тема шире списка целей, модуль говорит об этом прямо и отделяет экзаменационную
практику от фона. Команды берутся только из официальной документации RHEL 10 и
`man`, а «ожидаемые выводы» снимаются с живого прогона на стенде.

## Модули

| Модуль | Цели EX200 | Статус |
|---|---|---|
| `01-kernel-boot-grubby` | Modify the system bootloader | готов, выводы сняты 2026-10-05 (пункты 1.3 и 4.6 — 2026-10-06), QA зелёный на 2026-10-05 |
| `02-kernel-modules` | отдельной цели нет; опирается на Modify the system bootloader, Start and stop services…, Locate and interpret system log files and journals | готов, выводы сняты 2026-10-05 и 2026-10-06, QA зелёный |
| `03-memory` | Identify CPU/memory intensive processes and kill processes; Add new partitions and logical volumes, and swap to a system non-destructively; Locate and interpret system log files and journals | готов, выводы сняты 2026-10-05 и 2026-10-06, QA зелёный |
| `04-boot-interrupt-rd-break` | Interrupt the boot process in order to gain access to a system | готов, выводы сняты 2026-10-09 на консоли стенда (EC2 Serial Console), QA зелёный |
| `05-systemd-targets` | Boot systems into different targets manually; смежно — Boot, reboot, and shut down a system normally, Modify the system bootloader | готов, выводы сняты 2026-10-05 (target'ы, rescue/emergency) и 2026-10-10 (systemd-analyze), QA зелёный |
| `06-udev-persistent-naming` | Configure systems to mount file systems at boot by universally unique ID (UUID) or label; смежно — Create, mount, unmount, and use VFAT, ext4, and XFS file systems | готов, выводы сняты 2026-10-10, QA зелёный |

## Стенд

VM `rhel10-lab` в AWS: RHEL 10.2, x86_64, 2 vCPU / 2 GB, два пустых диска по 5 GB.
Как она создана, сколько стоит и как подключиться — `/root/aws/rhel-lab/README.md`.

```bash
ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip>   # ментор
ssh ec2-user@<public_ip>                                                                            # ученик, своим ключом
```

Вход только по ключу, пользователь `ec2-user`, root — через `sudo -i`. Консоли у
стенда нет, а учётная запись root заблокирована, отсюда три ограничения:

- переход в `rescue.target` или `emergency.target` без ментора не выполняется: из
  аварийного режима по SSH не выйти;
- initramfs не пересобирается (`dracut -f`): ошибка в образе оставит машину без
  загрузки;
- сетевые интерфейсы, появляющиеся при старте (модуль `dummy` с `numdummies` больше
  нуля), растягивают загрузку до пяти минут — см. `02-kernel-modules`, часть 3.3.

Имена дисков `nvme` на стенде меняются от загрузки к загрузке; диски различают по
серийному номеру (`lsblk -o NAME,SIZE,SERIAL`) и UUID.

Копия этого каталога лежит на стенде в `~/rhel-labs`. Обновить её после правок:

```bash
tar -C /root/menti/dovlet --exclude=.git --exclude=__pycache__ -czf - rhel-labs | ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip> 'tar -xzf - -C ~'
```

## Формат модуля

Тот же стандарт, что в `/root/lern/labs/linux-process-isolation`:

```text
NN-имя/
  README.md        методичка: части с теорией, шагами и реальными выводами
  LESSON-PLAN.md   план занятия для ментора
  ANSWERS.md       ответы на контрольные и итоговые вопросы
  run.sh           сводка состояния, ничего не меняет
  lib.sh           общие функции скриптов модуля
  tasks/           задания в формате экзамена: цель, задача, проверка, результат
  memhog.py        (только 03-memory) учебная программа для опытов с памятью
  broken/          инциденты: README с разбором и make-broken.sh
  solutions/       исправления инцидентов
  verify/          prepare.sh, verify.sh, cleanup.sh
```

## Проверка

```bash
sudo ./scripts/qa/run-module.sh 01-kernel-boot-grubby   # на стенде: prepare → verify → cleanup
sudo ./scripts/qa/run-module.sh 02-kernel-modules
sudo ./scripts/qa/run-module.sh 03-memory
./scripts/qa/lint.sh                                    # shellcheck, синтаксис Python и разметка README
```

`verify.sh` печатает `[OK]` / `[WARN]` / `[FAIL]` и останавливается на первой
проваленной проверке. `cleanup.sh` вызывается после проверки всегда, даже если она
упала. Исключение одно: если `verify.sh` отказался начинать, потому что на стенде
лежит незаконченная работа ученика, `cleanup.sh` не запускается и состояние стенда
остаётся как было.

## Правила материалов

- Цель экзамена в каждом задании приводится дословно по-английски.
- В скриптах нет комментариев; пояснения — в README модуля.
- `cleanup.sh` без ключей возвращает настройки и ничего не удаляет. То, что требует
  удаления (файлы лабы в `/etc`, учебный раздел), он только перечисляет с пометкой
  `[DRY-RUN]`. Удаление выполняет запуск `cleanup.sh --apply`, и запускает его
  человек.
- Экзамен — RHCSA (EX200), версия для RHEL 10; список целей сверяется со страницей
  экзамена при подготовке каждого модуля (последняя сверка 2026-10-10).
