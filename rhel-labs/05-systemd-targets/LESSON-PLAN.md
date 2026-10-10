# План занятия 05: systemd — target'ы и анализ загрузки

Документ для ментора. Материал для ученика — `README.md`, задания — `tasks/`, ответы —
`ANSWERS.md`.

## Рамка

| | |
|---|---|
| Цель экзамена | EX200 (RHEL 10): **Boot systems into different targets manually**; смежно — **Boot, reboot, and shut down a system normally** |
| Вне целей | `systemd-analyze` — смежный инструмент (документация RHEL 10, 5.1), не отдельная цель экзамена |
| Длительность | 60 минут |
| Стенд | `rhel10-lab`, RHEL 10.2, `systemd-257`. Выводы в README сняты 2026-10-05 (target'ы, rescue/emergency) и 2026-10-10 (`systemd-analyze`) |
| Результат | ученик переключает target на лету и по умолчанию, отличает разовую правку от постоянной, читает `systemd-analyze` и объясняет, почему rescue/emergency упираются в пароль root |

Большая часть занятия идёт по SSH. Но части 2.2–2.3 (rescue/emergency) и оба инцидента
**уводят систему туда, где нет SSH**, — их показывают только при открытой консоли
(консоль открывает ментор). Это главное предупреждение занятия.

## Перед занятием

1. Проверьте, что стенд здоров:
   ```bash
   ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip>
   cd ~/rhel-labs && sudo ./scripts/qa/run-module.sh 05-systemd-targets
   ```
   Ожидается зелёный `verify`: target по умолчанию `multi-user.target`, нет `systemd.unit=`
   в записях, система в `multi-user.target`, `systemd-analyze` читает прошлую загрузку.
2. Держите наготове консоль (EC2 Serial Console, `/root/aws/rhel-lab/serial-console.sh`):
   части 2.2–2.3 и инциденты без неё не отыграть и не восстановить.
3. Перезагрузки согласуйте заранее — в этом модуле их несколько.

Каталог `~ec2-user/rhel-labs` на стенде — копия `/root/menti/dovlet/rhel-labs`. После
правок материалов копию обновите.

## Ход занятия

| Время | Блок | Что делает ученик | На что смотреть |
|---|---|---|---|
| 0–10 | Что такое target | `list-units --type target`, `get-default`, `cat multi-user.target` | Видит ли Requires/Conflicts/AllowIsolate |
| 10–20 | isolate на лету | `isolate graphical.target` и обратно, `isolate basic.target` (отказ) | Понимает, что multi-user остаётся активным |
| 20–30 | rescue/emergency (консоль) | `systemctl rescue`; смотрит, что сеть и sshd стоят | Доходит ли, почему SSH тут не помощник |
| 30–40 | target по умолчанию | `set-default graphical`, перезагрузка, назад | Отличает set-default от isolate |
| 40–50 | systemd-analyze | `systemd-analyze`, `blame`, `critical-chain` | Не путает blame с общим временем |
| 50–60 | Инцидент | Разбирает инцидент 1 или 2 | Идёт от симптома (`get-default` / `/proc/cmdline`) к причине |

## Опорные вопросы по ходу

Задавайте до того, как ученик выполнит шаг, — пусть сначала предскажет.

1. Перед `isolate graphical`: «Останется ли `sshd` после переключения?» (да, graphical
   требует multi-user).
2. Перед `systemctl rescue`: «Чей пароль спросит rescue — и почему на стенде он не даёт
   оболочку?» (root установленной системы; root заблокирован → `sulogin` отказывает).
3. Перед `set-default`: «Изменит ли это текущий режим?» (нет, только следующую загрузку).
4. Перед инцидентом 2: «Если `get-default` = multi-user, можно ли всё равно загрузиться в
   rescue?» (да, через `systemd.unit=` на cmdline).
5. На `systemd-analyze blame`: «Сложив все строки, получим общее время загрузки?» (нет).

## Трудные места

**rescue/emergency по SSH.** Самая частая ошибка — запустить `systemctl rescue`/`emergency`
или `isolate rescue.target` по SSH без консоли. `emergency` рвёт соединение сразу
(поймано: `Connection closed by remote host`, новый коннект `Connection refused`). Всегда
открывайте консоль заранее.

**get-default против реальности.** Инцидент 2 ловит почти всех: `get-default` показывает
`multi-user.target`, а грузится rescue. Научите рефлексу: расхождение → `cat /proc/cmdline`.

**blame ≠ общее время.** `blame` наверху показывает `*.device`-юниты (ожидание устройства),
их времена идут параллельно и не складываются. Настоящую задержку показывает
`critical-chain`.

## Типичные ошибки

| Ошибка | Как проявляется | Что показать |
|---|---|---|
| `systemctl rescue`/`emergency` по SSH | сессия рвётся, вернуть нечем | README, часть 2; делать только с консоли |
| `set-default rescue.target` вместо разовой правки | после reboot нет SSH | `broken/scenario-01` |
| `systemd.unit=` дописан в запись через grubby | грузится не тот target, get-default «врёт» | `broken/scenario-02` |
| Сложение времён из `blame` | «боот 300 секунд» | часть 4; `critical-chain` |
| `isolate basic.target` | `Operation refused` | `AllowIsolate=no`, часть 1 |

## Критерии «тема усвоена»

- Объясняет связь target ↔ runlevel и что такое isolate.
- Отличает `isolate` (на сессию) от `set-default` (постоянно, симлинк).
- Знает, почему rescue/emergency требуют пароль root, а `rd.break` — нет.
- При расхождении `get-default` и реальности первым смотрит `/proc/cmdline`.
- Читает `systemd-analyze`/`blame`/`critical-chain` и не путает blame с общим временем.

## Домашнее задание

1. Повторить `tasks/01` и `tasks/02` без README, засекая время.
2. Разобрать инцидент, который не брали на занятии.
3. Прочитать раздел 5.1 документации RHEL 10 и `man 1 systemd-analyze`; найти у себя
   самый долгий юнит и критическую цепочку, объяснить разницу.

## После занятия

```bash
sudo ./verify/cleanup.sh
sudo systemctl reboot    # если в ходе занятия меняли target/cmdline
```

`cleanup.sh` убирает `systemd.unit=` из записей и возвращает target по умолчанию на
`multi-user.target`, ничего не удаляя. Если система осталась в rescue — вернуть
`systemctl default` или перезагрузкой.

## Источники

- Цели экзамена EX200:
  <https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam>
- RHEL 10, «Using systemd unit files to customize and optimize your system», гл. 3
  «Booting into a target system state»:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_systemd_unit_files_to_customize_and_optimize_your_system/booting-into-a-target-system-state>
- Там же, гл. 5 «Optimizing systemd to shorten the boot time», 5.1:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_systemd_unit_files_to_customize_and_optimize_your_system/optimizing-systemd-to-shorten-the-boot-time>
- `man 5 systemd.target`, `man 7 systemd.special`, `man 7 bootup`, `man 1 systemctl`,
  `man 1 systemd-analyze` на стенде.
