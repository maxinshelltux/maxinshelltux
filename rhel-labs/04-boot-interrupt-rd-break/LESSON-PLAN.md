# План занятия 04: прервать загрузку и сбросить пароль root (rd.break)

Документ для ментора. Материал для ученика — `README.md`, задания — `tasks/`, ответы —
`ANSWERS.md`.

## Рамка

| | |
|---|---|
| Цель экзамена | EX200 (RHEL 10): **Interrupt the boot process in order to gain access to a system** |
| Сопутствующие цели | Change passwords and adjust password aging for local user accounts; Restore default file contexts; List and identify SELinux file and process context; Set enforcing and permissive modes for SELinux; Modify the system bootloader; Boot, reboot, and shut down a system normally |
| Длительность | 60 минут |
| Стенд | `rhel10-lab`, RHEL 10.2; подготовлен ментором (меню GRUB в последовательной консоли). Выводы в README сняты 2026-10-09 при трёх ядрах |
| Результат | ученик сам сбрасывает пароль root через `rd.break`, доводит систему до рабочего состояния с Enforcing и объясняет роль `/.autorelabel` |

Это единственный модуль курса, который идёт **в консоли**, а не по SSH. Консоль
открывает ментор (у ученика нет доступа к AWS). Главная мысль занятия: вмешательство в
загрузку требует консоли, а сброс пароля не закончен, пока система не перезагрузилась
сама и не пустила root с новым паролем в Enforcing.

## Перед занятием

1. Проверьте, что стенд подготовлен и здоров:
   ```bash
   ssh -i /root/.ssh/vast -o UserKnownHostsFile=/root/aws/rhel-lab/known_hosts ec2-user@<public_ip>
   cd ~/rhel-labs && sudo ./scripts/qa/run-module.sh 04-boot-interrupt-rd-break
   ```
   Ожидается зелёный `verify` и `[WARN]`, что root заблокирован (это норма до занятия).
   Если меню GRUB в консоли не настроено — см. README, «Как подготовлен стенд».
2. Откройте ученику последовательную консоль. На стенде (AWS) это EC2 Serial Console;
   как — `/root/aws/rhel-lab/README.md` и скрипт `serial-console.sh` (`student`).
3. Убедитесь, что по SSH никто не работает: инциденты из части 5 обрывают SSH.

Каталог `~ec2-user/rhel-labs` на стенде — копия `/root/menti/dovlet/rhel-labs`. После
правок материалов копию нужно обновить.

## Ход занятия

| Время | Блок | Что делает ученик | На что смотреть |
|---|---|---|---|
| 0–10 | Консоль | Подключается к консоли, видит приглашение входа, объясняет, почему SSH тут не помогает | Понимает, что `ttyS0` — это `/dev/console` |
| 10–20 | Меню GRUB | Перезагружает, ловит меню, открывает редактор `e`, находит строку `linux` | Доходит ли до конца строки через `Ctrl+e` |
| 20–30 | rd.break | Дописывает `rd.break`, `Ctrl+x`, получает оболочку, смотрит `/proc/cmdline` | Видит ли `rd.break` и `/sysroot` |
| 30–45 | Сброс пароля | `remount,rw`, `chroot`, `passwd`, `touch /.autorelabel`, `exit exit`, ждёт перемаркировку | Не забывает ли `/.autorelabel` |
| 45–55 | Проверка | После перезагрузки: `ls -Z /etc/shadow`, `getenforce`, `passwd -S root`, вход под root | Проверяет ли на загруженной системе |
| 55–60 | Инцидент | Разбирает инцидент 1 или 2 на выбор | Идёт ли от симптома к причине |

Перемаркировка на стенде занимает меньше минуты; на экзаменационной технике может быть
дольше — предупредите, что это нормально.

## Опорные вопросы по ходу

Задавайте до того, как ученик выполнит шаг, — пусть сначала предскажет.

1. Перед частью 2: «Почему пароль root нельзя сбросить по SSH?»
2. Перед `rd.break`: «Чей пароль спросит оболочка — установленной системы или
   initramfs?» (initramfs; на стенде он пустой).
3. Перед `passwd`: «Почему сначала `mount -o remount,rw /sysroot` и `chroot`?»
4. Перед `exit`: «Что будет, если забыть `touch /.autorelabel`?» Это ключевой момент:
   система запрётся (инцидент 1).
5. После перезагрузки: «Как доказать, что задание выполнено?» (`passwd -S root` = P,
   `getenforce` = Enforcing, метка `shadow_t`, вход под root).

## Трудные места

**`restorecon` из оболочки `rd.break` не чинит метку.** Это ловит многих: в аварийной
оболочке SELinux не загружен, и `restorecon` молча ничего не меняет (проверено на стенде
2026-10-09). Из `rd.break` метку чинит только `touch /.autorelabel` и перемаркировка. А
`restorecon -v /etc/shadow` помогает, лишь когда у вас уже есть рабочий root-шелл
(система загружена, пусть и в permissive).

**Разовая правка против постоянной.** Напомните связь с лабой 01: `e` в меню — одна
загрузка, `grubby --args` — навсегда. Отсюда правило: `rd.break` задают только через
меню; постоянным его не делают (инцидент про недоступную машину).

## Типичные ошибки

| Ошибка | Как проявляется | Что показать |
|---|---|---|
| Забыл `touch /.autorelabel` | после сброса не пускает, SSH рвётся | `broken/scenario-01` |
| `restorecon` в оболочке rd.break | метка не меняется | README, часть 5; `solutions/01` |
| `rd.break` дописан в середину строки linux | ядро не грузится / параметр не распознан | `Ctrl+e` до конца строки, часть 2.2 |
| `enforcing=0` прописан в запись | после перезагрузки permissive | `broken/scenario-02` |
| Проверка без перезагрузки | «пароль сменил», но система не проверена | часть 4.4 |

## Критерии «тема усвоена»

- Объясняет, почему для сброса пароля нужна консоль, а не SSH.
- По памяти воспроизводит последовательность: меню → `e` → `rd.break` → `Ctrl+x` →
  `remount,rw` → `chroot` → `passwd` → `touch /.autorelabel` → `exit exit`.
- Называет роль `/.autorelabel` и что будет без него.
- Доказывает результат на загруженной системе (`passwd -S root`, `getenforce`, метка).
- Отличает разовую правку в меню от постоянного `grubby --args`.

## Домашнее задание

1. Повторить `tasks/01` с нуля, без README, засекая время.
2. Разобрать второй инцидент из `broken/`, который не брали на занятии.
3. Прочитать разделы 4.5 и 4.6 документации RHEL 10 и сформулировать, чем разовая
   правка в меню отличается от настройки консоли через `/etc/default/grub`.

## После занятия

```bash
sudo ./verify/cleanup.sh
sudo passwd -l root        # вернуть root в заблокированное состояние
sudo systemctl reboot
```

Настройку GRUB для консоли `cleanup.sh` не трогает — это подготовка стенда. Если в ходе
инцидентов менялись метки или параметры, `cleanup.sh` и `solutions/*/fix.sh` их
возвращают.

## Источники

- Цели экзамена EX200:
  <https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam>
- RHEL 10, «Managing, monitoring, and updating the kernel», разделы 4.5–4.6:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_monitoring_and_updating_the_kernel/configuring-kernel-command-line-parameters>
- RHEL 9, «Configuring basic system settings», 7.6.3 «Resetting the root password»:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_basic_system_settings/managing-users-and-groups_configuring-basic-system-settings>
- RHEL 8, «Managing, monitoring, and updating the kernel», 6.8 «Resetting the root password using rd.break».
- `man 7 dracut.cmdline`, `man 8 sulogin`, `man 8 selinux`, `man 5 selinux_config`,
  `man 8 restorecon` на стенде.
