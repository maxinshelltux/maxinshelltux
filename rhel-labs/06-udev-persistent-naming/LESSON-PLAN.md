# План занятия 06: udev и постоянные имена устройств

Документ для ментора. Материал для ученика — `README.md`, задания — `tasks/`, ответы —
`ANSWERS.md`.

## Рамка

| | |
|---|---|
| Цель экзамена | EX200 (RHEL 10): **Configure systems to mount file systems at boot by universally unique ID (UUID) or label** |
| Вне целей | правила udev — смежный материал (документация RHEL 10, 2.2), не отдельная цель |
| Длительность | 60 минут |
| Стенд | `rhel10-lab`, RHEL 10.2, `systemd-udev-257`. Выводы в README сняты 2026-10-10 |
| Результат | ученик находит постоянные имена диска, монтирует ФС по UUID с `nofail`, пишет и отлаживает правило udev, объясняет, почему имена ядра неустойчивы |

Большая часть занятия идёт по SSH. Исключение — инцидент 1 (сбойный `/etc/fstab`): после
перезагрузки он уводит систему в emergency, вернуть можно только с консоли (её открывает
ментор). Инцидент 2 и все задания безопасны по SSH.

## Перед занятием

1. Проверьте, что стенд здоров:
   ```bash
   ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip>
   cd ~/rhel-labs && sudo ./scripts/qa/run-module.sh 06-udev-persistent-naming
   ```
   Ожидается зелёный `verify`: каталоги постоянных имён на месте, fstab по UUID, нет
   учебных правил udev и симлинков `/dev/lab-*`.
2. Убедитесь, что на стенде есть пустой запасной диск (в `lsblk` — диск без ФС и
   разделов). Задания 02–03 опираются на него.
3. Для инцидента 1 держите наготове консоль (EC2 Serial Console) — без неё из emergency
   не вернуться. Перезагрузки согласуйте.

Каталог `~ec2-user/rhel-labs` на стенде — копия `/root/menti/dovlet/rhel-labs`. После
правок материалов копию обновите.

## Ход занятия

| Время | Блок | Что делает ученик | На что смотреть |
|---|---|---|---|
| 0–10 | Имена «плавают» | `lsblk`, сравнивает имя ядра с `by-id`/`by-path` | Понимает, что `nvme`-имя не закреплено |
| 10–20 | /dev/disk/by-* | разбирает by-uuid/label/id/path на реальных дисках | Различает, что к чему привязано |
| 20–30 | Монтирование по UUID | `blkid`, запись в fstab по UUID с nofail, `mount -a` | Не забывает `nofail` и `findmnt --verify` |
| 30–45 | udev и udevadm | `udevadm info/monitor/trigger`, правило со SYMLINK | Кладёт правило в /etc, делает reload |
| 45–55 | Инцидент 2 (udev) | правило не сработало, отладка `udevadm test` | Сверяет ключ ID_SERIAL vs ID_SERIAL_SHORT |
| 55–60 | Инцидент 1 (fstab) | разбор на консоли или `findmnt --verify` | Видит связь с целью экзамена |

## Опорные вопросы по ходу

Задавайте до того, как ученик выполнит шаг, — пусть сначала предскажет.

1. Перед fstab: «Что будет после перезагрузки, если в fstab написать `/dev/nvme1n1`?»
2. Перед `mount -a`: «Зачем `nofail`? Что без него при сбое монтирования?» (emergency).
3. Перед правилом udev: «Куда класть файл — в `/usr/lib/udev/rules.d` или `/etc/udev/rules.d`?»
4. После правки правила: «Почему симлинк не появился сразу? Что нужно сделать?» (reload).
5. На инциденте 2: «У диска есть ID_SERIAL и ID_SERIAL_SHORT — это одно и то же?» (нет).

## Трудные места

**fstab по имени ядра = ловушка.** Главный смысл занятия: имена ядра неустойчивы, в fstab
— только UUID/LABEL и `nofail`. Проверка записи `findmnt --verify` **до** перезагрузки.

**reload после правки правила.** Частая ошибка — поправить `*.rules` и ждать эффекта без
`udevadm control --reload`. Правила перечитываются только по reload.

**ID_SERIAL vs ID_SERIAL_SHORT.** Разные свойства; подставлять надо значение того ключа,
который сравниваешь. Отладка — `udevadm test`.

## Типичные ошибки

| Ошибка | Как проявляется | Что показать |
|---|---|---|
| fstab по `/dev/имя-ядра`, без nofail | после reboot — emergency | `broken/scenario-01` |
| забыл `udevadm control --reload` | правило не действует | часть 3; `broken/scenario-02` |
| перепутал ID_SERIAL и ID_SERIAL_SHORT | симлинк не появляется | `broken/scenario-02` |
| правило в `/usr/lib/udev/rules.d` | затирается обновлением | часть 3, README |
| `mkfs` не на тот диск | потеря данных | часть 2, предупреждение |

## Критерии «тема усвоена»

- Объясняет, почему имя ядра нельзя писать в fstab, и чем `by-uuid`/`by-id`/`by-path`
  отличаются.
- Монтирует ФС по UUID с `nofail` и проверяет `findmnt --verify` до перезагрузки.
- Находит постоянные имена и серийник устройства через `udevadm info`.
- Пишет правило udev со SYMLINK в `/etc/udev/rules.d`, применяет через reload/trigger.
- Отлаживает несработавшее правило через `udevadm test`.

## Домашнее задание

1. Повторить задание 02 (монтирование по UUID) с нуля, без README.
2. Разобрать инцидент, который не брали на занятии.
3. Прочитать `man 7 udev` раздел про ключи правил и написать правило, которое по
   `ID_SERIAL_SHORT` даёт диску свой симлинк и владельца (`OWNER`/`GROUP`/`MODE`).

## После занятия

```bash
sudo ./verify/cleanup.sh
# если делали задание 02 (fstab/монтирование) — вернуть вручную:
#   sudo umount /mnt/labdata; убрать строку из /etc/fstab; sudo wipefs -a <диск>
```

`cleanup.sh` убирает учебные правила udev и перечитывает их. Файл `/etc/fstab` он не
трогает (предупреждает, если там осталась запись по имени ядра) — правьте через
`solutions/01-fstab-persistent` или вручную.

## Источники

- Цели экзамена EX200:
  <https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam>
- RHEL 10, «Managing storage devices», глава 2 «Persistent naming attributes» (2.1, 2.2):
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_storage_devices/persistent-naming-attributes>
- `man 7 udev`, `man 8 udevadm`, `man 5 fstab`, `man 8 mount` на стенде.
