# rhel-labs — практика к экзамену RHCSA (EX200, RHEL 10)

Лабораторные работы для подготовки к сертификации. Каждый модуль закрывает
конкретные цели экзамена EX200 и называет их дословно, со ссылкой на
[страницу экзамена](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam).
Команды берутся только из официальной документации RHEL 10 и `man`, а «ожидаемые
выводы» снимаются с живого прогона на стенде.

## Модули

| Модуль | Цель EX200 | Статус |
|---|---|---|
| `01-kernel-boot-grubby` | Modify the system bootloader | готов, выводы сняты 2026-10-05, QA зелёный |

## Стенд

VM `rhel10-lab` в AWS: RHEL 10.2, x86_64, 2 vCPU / 2 GB, два пустых диска по 5 GB.
Как она создана, сколько стоит и как подключиться — `/root/aws/rhel-lab/README.md`.

```bash
ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip>   # ментор
ssh ec2-user@<public_ip>                                                                            # ученик, своим ключом
```

Вход только по ключу, пользователь `ec2-user`, root — через `sudo -i`. Консоли у
стенда нет, а учётная запись root заблокирована, поэтому переход в `rescue.target`
или `emergency.target` на нём без ментора не выполняется: из аварийного режима по SSH
не выйти.

Копия этого каталога лежит на стенде в `~/rhel-labs`. Обновить её после правок:

```bash
tar -C /root/menti/dovlet --exclude=.git -czf - rhel-labs | ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip> 'tar -xzf - -C ~'
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
  broken/          инциденты: README с разбором и make-broken.sh
  solutions/       исправления инцидентов
  verify/          prepare.sh, verify.sh, cleanup.sh
```

## Проверка

```bash
sudo ./scripts/qa/run-module.sh 01-kernel-boot-grubby   # на стенде: prepare → verify → cleanup
./scripts/qa/lint.sh                                    # shellcheck и разметка README
```

`verify.sh` печатает `[OK]` / `[WARN]` / `[FAIL]` и останавливается на первой
проваленной проверке. `cleanup.sh` вызывается всегда, даже если проверка упала.

## Правила материалов

- Цель экзамена в каждом задании приводится дословно по-английски.
- В скриптах нет комментариев; пояснения — в README модуля.
- Скрипты ничего не удаляют. `cleanup.sh` возвращает настройки, а не стирает файлы.
- Экзамен — RHCSA (EX200), версия для RHEL 10; список целей сверяется со страницей
  экзамена при подготовке каждого модуля (последняя сверка 2026-10-05).
