# Лабораторная работа 04: прервать загрузку и получить доступ к системе (rd.break)

## Оглавление
<!-- TOC -->
- [Соответствие целям экзамена RHCSA](#соответствие-целям-экзамена-rhcsa)
- [Откуда взята процедура](#откуда-взята-процедура)
- [Предварительные требования](#предварительные-требования)
- [Стартовая проверка](#стартовая-проверка)
- [Часть 1: Консоль](#часть-1-консоль)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью)
  - [1.1 Куда подключён ваш SSH и чего в нём не видно](#11-куда-подключён-ваш-ssh-и-чего-в-нём-не-видно)
  - [1.2 Приглашение входа в консоли](#12-приглашение-входа-в-консоли)
- [Часть 2: Меню GRUB и разовая правка параметров](#часть-2-меню-grub-и-разовая-правка-параметров)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-1)
  - [2.1 Остановить загрузку в меню](#21-остановить-загрузку-в-меню)
  - [2.2 Редактор строки linux](#22-редактор-строки-linux)
- [Часть 3: rd.break — оболочка до корневой системы](#часть-3-rdbreak--оболочка-до-корневой-системы)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-2)
  - [3.1 Что лежит в initramfs](#31-что-лежит-в-initramfs)
  - [3.2 Получить оболочку rd.break](#32-получить-оболочку-rdbreak)
- [Часть 4: Сбросить пароль root](#часть-4-сбросить-пароль-root)
  - [Теория для изучения перед частью](#теория-для-изучения-перед-частью-3)
  - [4.1 Перемонтировать корень и войти в chroot](#41-перемонтировать-корень-и-войти-в-chroot)
  - [4.2 Задать пароль и запросить перемаркировку](#42-задать-пароль-и-запросить-перемаркировку)
  - [4.3 Продолжить загрузку и дождаться перемаркировки](#43-продолжить-загрузку-и-дождаться-перемаркировки)
  - [4.4 Доказать результат](#44-доказать-результат)
- [Часть 5: Troubleshooting](#часть-5-troubleshooting)
  - [Теория: диагностика по симптому](#теория-диагностика-по-симптому)
  - [Инцидент 1: после сброса пароля вход не работает](#инцидент-1-после-сброса-пароля-вход-не-работает)
  - [Инцидент 2: система грузится в permissive](#инцидент-2-система-грузится-в-permissive)
- [Как подготовлен стенд](#как-подготовлен-стенд)
- [Проверка модуля](#проверка-модуля)
- [Теоретические вопросы (итоговые)](#теоретические-вопросы-итоговые)
- [Практические задания (отработка)](#практические-задания-отработка)
- [Шпаргалка](#шпаргалка)
- [Чему вы научились](#чему-вы-научились)
- [Уборка](#уборка)
<!-- /TOC -->

> ⏱ время ~60 мин (с 3–4 перезагрузками и одной перемаркировкой) · сложность 3/5 · пререквизиты: лаба 01, консоль стенда (её открывает ментор)

Цель: научиться вмешиваться в загрузку системы, к которой нет обычного входа, — так,
как этого требует цель экзамена *Interrupt the boot process in order to gain access to
a system*. Типовая постановка экзамена и жизни: пароль root неизвестен, нужно получить
доступ, задать новый пароль и оставить систему в рабочем состоянии, переживающем
перезагрузку.

> Все «ожидаемые выводы» сняты 2026-10-09 на стенде `rhel10-lab`: RHEL 10.2, AWS
> `t3.small`, UEFI, `grub2-2.12-46.el10_2`, `dracut-107-9.el10_2`,
> `selinux-policy-42.1.18`, ядро по умолчанию `6.12.0-211.62.1.el10_2`, на стенде три
> ядра. Консоль — EC2 Serial Console (последовательный порт `ttyS0`). У вас версии
> ядер, UUID корня и имя узла будут свои — важна **структура** вывода.
>
> Экраны GRUB рисуются символами псевдографики; здесь рамки для читаемости заменены на
> `+`, `-` и `|`, текст внутри — как в консоли.

---

## Соответствие целям экзамена RHCSA

Формулировки целей приведены дословно со
[страницы экзамена EX200](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
(версия для Red Hat Enterprise Linux 10, сверено 2026-10-09; Red Hat может менять
список — перед экзаменом перечитайте страницу).

| Что делаем в модуле | Цель EX200 (дословно) | Раздел целей |
|---|---|---|
| Остановить загрузку в меню GRUB, дописать `rd.break` на одну загрузку, получить оболочку (части 2–3, задание 01) | Interrupt the boot process in order to gain access to a system | Operate running systems |
| Перезагрузки и проверка, что после вмешательства система загружается сама (часть 4) | Boot, reboot, and shut down a system normally | Operate running systems |
| Задать новый пароль root (часть 4, задание 01) | Change passwords and adjust password aging for local user accounts | Manage users and groups |
| Метка `/etc/shadow` до и после сброса (части 4–5) | List and identify SELinux file and process context | Manage security |
| Вернуть файлу правильную метку (часть 5, задание 02) | Restore default file contexts | Manage security |
| Разовая загрузка с `enforcing=0` (часть 5) | Set enforcing and permissive modes for SELinux | Manage security |
| Убрать `rd.break`/`enforcing=0`, оставшиеся в записях (часть 5, задание 03) | Modify the system bootloader | Deploy, configure, and maintain systems |
| `man 7 dracut.cmdline`, `man 8 sulogin`, `man 8 selinux` | Locate, read, and use system documentation including man, info, and files in /usr/share/doc | Understand and use essential tools |

Общее требование экзамена с той же страницы: «As with all Red Hat performance-based
exams, configurations must persist after reboot without intervention». Для этой лабы
оно означает: после сброса пароля система должна загрузиться сама, с SELinux в режиме
Enforcing, и пустить вас под root с новым паролем.

Соседняя цель, которую модуль **не** закрывает: *Boot systems into different targets
manually* — загрузка в `rescue.target` и `emergency.target` через параметр
`systemd.unit=`. Это отдельное занятие; здесь эти цели упоминаются только для сравнения
с `rd.break`.

---

## Откуда взята процедура

В документации RHEL 10 процедуры сброса пароля root найти не удалось (проверено
2026-10-09). Просмотрены книги «Managing, monitoring, and updating the kernel»,
«Security hardening» и «Risk reduction and recovery operations». В первой есть только
две смежные процедуры:

- раздел 4.5 «Changing kernel command-line parameters temporarily at boot time» —
  разовая правка параметров в меню GRUB;
- раздел 4.6 «Configuring GRUB settings to enable serial console connection» — вывод
  меню GRUB в последовательный порт.

Сама процедура с `rd.break` описана для предыдущих версий:

- RHEL 9, «Configuring basic system settings», раздел 7.6.3 «Resetting the root
  password»:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_basic_system_settings/managing-users-and-groups_configuring-basic-system-settings>
- RHEL 8, «Managing, monitoring, and updating the kernel», раздел 6.8 «Resetting the
  root password using rd.break» — там же запасной путь через `enforcing=0`:
  <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/managing_monitoring_and_updating_the_kernel/assembly_making-temporary-changes-to-the-grub-menu_managing-monitoring-and-updating-the-kernel>

Параметр `rd.break` в RHEL 10 никуда не делся: он описан в `man 7 dracut.cmdline` на
стенде (`dracut-107-9.el10_2`). Вся процедура ниже проверена на стенде RHEL 10.2
2026-10-09, от меню GRUB до входа после перемаркировки. Где RHEL 10 ведёт себя иначе,
чем в тексте RHEL 9, шаг говорит об этом прямо.

---

## Предварительные требования

Этот модуль идёт целиком в консоли стенда. Консоль открывает ментор: у ученика нет
доступа к учётной записи AWS, а приглашение входа в консоли требует пароля (ключи SSH
там не действуют). Дальнейшие шаги вы выполняете в уже открытой консоли.

```bash
cat /etc/redhat-release
# Red Hat Enterprise Linux release 10.2 (Coughlan)
```

Стенд должен быть подготовлен: меню GRUB выводится в последовательный порт и ждёт
несколько секунд. Как это сделано — раздел «Как подготовлен стенд»; проверяет
готовность `sudo ./verify/prepare.sh`.

---

## Стартовая проверка

```bash
sudo ./run.sh | sed -n '/Меню GRUB/,/initramfs/p'
# === Меню GRUB ===
# GRUB_TIMEOUT:        5
# GRUB_TERMINAL:       console serial
# GRUB_SERIAL_COMMAND: serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
# timeout в grub.cfg:  5
# [OK] меню GRUB показывается в последовательной консоли и ждёт 5 с
```

`./run.sh` целиком показывает консоль, меню GRUB, параметры загрузки, содержимое
initramfs, режим SELinux и состояние пароля root. Запускайте его, когда нужно понять,
в каком состоянии стенд.

---

## Часть 1: Консоль

### Теория для изучения перед частью

- SSH появляется в самом конце загрузки: нужны сеть и служба `sshd`. Меню GRUB, старт
  ядра, работа initramfs происходят раньше и по SSH не видны. Вмешаться в загрузку
  можно только с консоли машины.
- Ядро выводит сообщения на устройства из параметра `console=`. На стенде их два:
  `console=tty0 console=ttyS0,115200n8`. `tty0` — экран, которого у виртуальной машины
  в AWS нет. `ttyS0` — первый последовательный порт; он и есть консоль стенда.
- Программы ранней загрузки разговаривают с человеком через `/dev/console` — это
  последнее устройство из перечисленных в `console=` (документация ядра
  `admin-guide/serial-console.rst`), то есть на стенде `ttyS0`.
- После загрузки на том же порту ждёт вход служба `serial-getty@ttyS0.service`. Войти
  там можно только с паролем; у root на стенде пароль по умолчанию заблокирован.
- К порту стенда подключаются через EC2 Serial Console. Сеанс консоли не зависит от
  операционной системы и переживает перезагрузку машины — поэтому перезагружаться
  можно, не отключаясь от консоли.
- Источники: документация AWS
  [Connect to the EC2 Serial Console](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-to-serial-console.html);
  `man 7 kernel-command-line`.

### 1.1 Куда подключён ваш SSH и чего в нём не видно

```bash
cat /sys/class/tty/console/active
# tty0 ttyS0

cat /proc/consoles
# ttyS0                -W- (EC p a)    4:64
# tty0                 -WU (E  p  )    4:1
```

`/dev/console` — последнее в списке `console=`, здесь `ttyS0`. Именно туда initramfs
и `sulogin` выведут приглашение в части 3.

### 1.2 Приглашение входа в консоли

Когда ментор подключит вас к консоли уже загруженной системы, вы увидите:

```text
Red Hat Enterprise Linux 10.2 (Coughlan)
Kernel 6.12.0-211.62.1.el10_2.x86_64 on x86_64

dava-rhel login:
```

Это `serial-getty@ttyS0`. Пароля root нет, войти под ним нельзя — в этом и задача
лабы: получить доступ в обход входа. Отсюда и начинается перезагрузка в части 2.

---

## Часть 2: Меню GRUB и разовая правка параметров

### Теория для изучения перед частью

- Запись загрузчика, которую вы меняли в лабе 01 через `grubby`, — постоянная
  настройка. Меню GRUB позволяет поправить параметры **одной** загрузки, не трогая
  записи.
- Порядок из документации RHEL 10 (раздел 4.5): дождаться меню, выбрать ядро, нажать
  `e`, перейти в конец строки `linux`, дописать параметр, нажать `Ctrl+x`. `Esc`
  отменяет правку и возвращает в меню.
- Правка живёт до следующей перезагрузки. Это тот же принцип, что в лабе 01:
  `/proc/cmdline` покажет параметр, а `grubby --info=DEFAULT` — нет.
- Источник: документация RHEL 10 «Managing, monitoring, and updating the kernel»,
  [раздел 4.5](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_monitoring_and_updating_the_kernel/configuring-kernel-command-line-parameters).

### 2.1 Остановить загрузку в меню

Перезагрузите систему (из консоли, если вошли, — `sudo systemctl reboot`; если входа
нет — ментор перезагрузит через API). Как только появится меню, нажмите любую стрелку,
чтобы остановить обратный отсчёт:

```text
                               GRUB version 2.12

 +----------------------------------------------------------------------------+
 | Red Hat Enterprise Linux (6.12.0-211.53.1.el10_2.x86_64) 10.2 (Coughlan)   |
 |*Red Hat Enterprise Linux (6.12.0-211.62.1.el10_2.x86_64) 10.2 (Coughlan)   |
 | Red Hat Enterprise Linux (6.12.0-211.61.1.el10_2.x86_64) 10.2 (Coughlan)   |
 | UEFI Firmware Settings                                                     |
 +----------------------------------------------------------------------------+

      Use the ^ and v keys to select which entry is highlighted.
      Press enter to boot the selected OS, `e' to edit the commands
      before booting or `c' for a command-line. ESC to return previous
      menu.
   The highlighted entry will be executed automatically in 5s.
```

`*` помечает ядро по умолчанию (на стенде `…62.1`). Порядок записей — тот же, что в
лабе 01 (часть 4.6).

### 2.2 Редактор строки linux

Выбрав стрелками нужную запись, нажмите `e`. Откроется её тело:

```text
 +----------------------------------------------------------------------------+
 |load_video                                                                  |
 |set gfxpayload=keep                                                         |
 |insmod gzio                                                                 |
 |linux ($root)/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64 root=UUID=c78c1f15\|
 |-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.\|
 |io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M  transparent_hugepa\|
 |ge=never                                                                    |
 |initrd ($root)/boot/initramfs-6.12.0-211.62.1.el10_2.x86_64.img $tuned_init\|
 |rd                                                                          |
 +----------------------------------------------------------------------------+

      Minimum Emacs-like screen editing is supported. TAB lists
      completions. Press Ctrl-x or F10 to boot, Ctrl-c or F2 for a
      command-line or ESC to discard edits and return to the GRUB menu.
```

Строка, которая начинается с `linux`, — командная строка ядра. Она логически одна,
хотя на экране переносится на несколько строк (знак `\` в конце — перенос, не часть
текста). Редактор понимает сочетания в стиле Emacs: `Ctrl+a` — в начало строки,
`Ctrl+e` — в конец. Чтобы приписать параметр в конец строки `linux`:

1. тремя нажатиями `стрелка вниз` встаньте на строку `linux` (под ней `load_video`,
   `set gfxpayload=keep`, `insmod gzio`);
2. `Ctrl+e` — курсор в конец строки, после `transparent_hugepage=never`;
3. наберите пробел и `rd.break`.

В части 3 вы нажмёте `Ctrl+x` и загрузитесь с этой правкой. Пока запомните: `Esc`
отменяет всё и возвращает в меню — ни одна правка в редакторе не меняет файлы на диске.

---

## Часть 3: rd.break — оболочка до корневой системы

### Теория для изучения перед частью

- Загрузка идёт в два приёма. Сначала ядро запускает маленькую систему из initramfs:
  её задача — найти корневой диск и смонтировать его в `/sysroot`. Затем она уступает
  место установленной системе: `/sysroot` становится корнем `/` (это и есть
  «switch_root»).
- `rd.break` читает не ядро, а initramfs (лаба 01, пункт 1.3). Параметр останавливает
  загрузку между этими двумя приёмами: корневой диск уже смонтирован в `/sysroot`, а
  установленная система ещё не запущена.
- Оболочку в этот момент даёт `sulogin` из initramfs. Он сверяет пароль с файлами
  **самого initramfs**, а не установленной системы. Поэтому `rd.break` помогает там,
  где пароль root неизвестен. Цели `rescue.target`/`emergency.target` так не умеют: они
  запускают `sulogin` уже в установленной системе и спрашивают её пароль root.
- У `rd.break` есть формы с точкой останова, например `rd.break=pre-mount` — до
  монтирования корня. Для сброса пароля нужна форма без значения — останов перед
  switch_root, когда `/sysroot` уже смонтирован.
- Источники: `man 7 dracut.cmdline`, `man 8 sulogin`, `man 1 lsinitrd`.

### 3.1 Что лежит в initramfs

Команды только читают образ (всё под root):

```bash
man 7 dracut.cmdline 2>/dev/null | grep -A1 -E '^ +rd\.break$'
#        rd.break
#            drop to a shell at the end

lsinitrd /boot/initramfs-$(uname -r).img -f etc/passwd
# adm:x:3:4:adm:/var/adm:/usr/sbin/nologin
# root::0:0::/root:/bin/sh
# nobody:x:65534:65534:Kernel Overflow User:/:/usr/sbin/nologin
```

Второе поле в строке `root` пустое: внутри initramfs у root нет пароля. Поэтому
оболочка `rd.break` не спрашивает пароль установленной системы — её пароль вообще не
участвует.

### 3.2 Получить оболочку rd.break

В редакторе из 2.2 вы дописали ` rd.break` в конец строки `linux`. Нажмите `Ctrl+x`.
Загрузка дойдёт до точки останова и остановится:

```text
[   12.575119] dracut-pre-pivot[508]: Warning: Break before switch_root
         Starting dracut-emergency.service - Dracut Emergency Shell...
Press Enter for maintenance
(or press Control-D to continue):
```

Нажмите Enter — появится оболочка. Приглашение на RHEL 10.2 — `sh-5.2#`:

```text
sh-5.2#
```

Убедитесь, что остановились именно из-за своего параметра:

```bash
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.62.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M transparent_hugepage=never rd.break
```

`rd.break` в конце — это ваша правка. Корневая файловая система уже смонтирована, но в
`/sysroot`, а не в `/`. В следующей части вы её перемонтируете и войдёте в неё.

---

## Часть 4: Сбросить пароль root

### Теория для изучения перед частью

- Из оболочки `rd.break` установленная система видна как каталог `/sysroot`.
  `chroot /sysroot` делает его корнем вашей оболочки: после этого `passwd` меняет
  `/etc/shadow` установленной системы, а не initramfs.
- `/sysroot` на этом этапе смонтирован только для чтения; перед правкой его
  перемонтируют на чтение-запись: `mount -o remount,rw /sysroot`.
- `touch /.autorelabel` — не формальность. В оболочке `rd.break` политика SELinux ещё
  не загружена, и файл, записанный `passwd`, может получить неверную метку. При
  включённом Enforcing с неверной меткой `/etc/shadow` вход потом не работает (это
  инцидент 1 из части 5). Файл `/.autorelabel` просит систему при следующей загрузке
  расставить метки заново по всей файловой системе, удалить файл и перезагрузиться ещё
  раз (`man 8 selinux`, `man 5 selinux_config`).
- Запасной путь из документации RHEL 8: загрузиться с `rd.break enforcing=0`, после
  входа выполнить `restorecon /etc/shadow` и `setenforce 1` — тогда перемаркировка всей
  системы не нужна. Минус: до `setenforce 1` система работает в permissive.
- Пароль root выбираете вы сами. Не записывайте его в файлы и не коммитьте в репозиторий.
- Источники: RHEL 9 (7.6.3) и RHEL 8 (6.8) по ссылкам выше, `man 8 selinux`,
  `man 8 restorecon`, `man 1 passwd`.

### 4.1 Перемонтировать корень и войти в chroot

```bash
mount -o remount,rw /sysroot
chroot /sysroot
```

Приглашение остаётся `sh-5.2#`, но теперь корень оболочки — установленная система.

### 4.2 Задать пароль и запросить перемаркировку

```bash
passwd
# New password:
# Retype new password:
# passwd: password updated successfully

touch /.autorelabel
```

`passwd` без имени меняет пароль root. Ввод не отображается. `touch /.autorelabel`
ставит метку о перемаркировке на корень установленной системы.

### 4.3 Продолжить загрузку и дождаться перемаркировки

```bash
exit   # выход из chroot
exit   # выход из оболочки rd.break — загрузка продолжится
```

Увидев `/.autorelabel`, система расставляет метки и перезагружается сама:

```text
         Starting selinux-autorelabel.service - Relabel all filesystems...
selinux-autorelabel[36405]: *** Warning -- SELinux targeted policy relabel is required.
selinux-autorelabel[36405]: *** Relabeling could take a very long time, depending on file
selinux-autorelabel[36405]: *** system size and speed of hard drives.
selinux-autorelabel[36405]: Running: /sbin/fixfiles -T 0  restore
```

На время перемаркировки SELinux переводится в permissive (в журнале появится
`enforcing=0 old_enforcing=1`) и возвращается в Enforcing после перезагрузки — это
делает сам сценарий `/usr/libexec/selinux/selinux-autorelabel`, вмешиваться не нужно.
На стенде (корень ~5 ГБ занятых) перемаркировка заняла меньше минуты; на больших
дисках она дольше. После неё система перезагрузится ещё раз и дойдёт до приглашения
входа.

### 4.4 Доказать результат

Задание выполнено только после проверки на загруженной системе:

```bash
ls /.autorelabel
# ls: cannot access '/.autorelabel': No such file or directory

ls -Z /etc/shadow
# system_u:object_r:shadow_t:s0 /etc/shadow

restorecon -n -v /etc/shadow
# (пусто — метка уже правильная, менять нечего)

getenforce
# Enforcing

passwd -S root
# root P 2026-10-09 0 99999 7 -1
```

`/.autorelabel` исчез (перемаркировка его удалила), метка `/etc/shadow` — `shadow_t`,
`restorecon -n` ничего не исправляет, SELinux в Enforcing, статус пароля root — `P`
(был `L` — заблокирован). Теперь в консоли можно войти под root с новым паролем.

---

## Часть 5: Troubleshooting

### Теория: диагностика по симптому

- «После сброса пароля не пускает» — почти всегда забытый `touch /.autorelabel`:
  `/etc/shadow` получил неверную метку, и при Enforcing модуль аутентификации не может
  его прочитать. Проверка — `ls -Z /etc/shadow` и `restorecon -n -v /etc/shadow`.
- «Система каждый раз останавливается на оболочке» — `rd.break` оставили в постоянной
  записи (например, `grubby --args`), а не только в разовой правке меню. Проверка —
  `grubby --info=DEFAULT`. Никогда не делайте `rd.break` постоянным параметром: без
  консоли система станет недоступна.
- «SELinux в permissive после перезагрузки» — в записи остался `enforcing=0` из
  запасного пути. Проверка — `/proc/cmdline` и `grubby --info=DEFAULT`.

### Инцидент 1: после сброса пароля вход не работает

Разбор и воспроизведение — `broken/scenario-01/`. Симптом: пароль задан, но вход под
root (и `su`/`sudo` по паролю) не проходит. Причина — неверная метка `/etc/shadow`.
Решение: `restorecon -v /etc/shadow` или `touch /.autorelabel` и перезагрузка. Разбор
— `solutions/01-shadow-relabel/`.

### Инцидент 2: система грузится в permissive

Разбор — `broken/scenario-02/`. Симптом: `getenforce` показывает `Permissive`, хотя в
`/etc/selinux/config` стоит `enforcing`. Причина — `enforcing=0` в записи загрузчика.
Решение: `grubby --update-kernel=ALL --remove-args="enforcing"` и перезагрузка. Разбор
— `solutions/02-remove-enforcing/`.

---

## Как подготовлен стенд

Чтобы меню GRUB было видно в последовательной консоли и ждало, ментор один раз
настроил загрузчик по разделу 4.6 документации RHEL 10. В `/etc/default/grub`
добавлены строки, остальное не тронуто:

```bash
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
```

Затем конфигурация пересобрана и проверена:

```bash
cp -a /boot/grub2/grub.cfg /root/lab04-grub-backup/      # копия на случай отката
grub2-mkconfig -o /boot/grub2/grub.cfg                   # без --update-bls-cmdline
grub2-script-check /boot/grub2/grub.cfg && echo ok
```

Ключ `--update-bls-cmdline` здесь **не используется** намеренно: он переписал бы строку
`options` каждой записи из `GRUB_CMDLINE_LINUX` и убрал бы `crashkernel=`. Без него
записи (`/boot/loader/entries/*.conf`) остаются нетронутыми — меняется только
`grub.cfg`. Скорость порта (`115200`) совпадает с `console=ttyS0,115200n8` в параметрах
ядра и со скоростью EC2 Serial Console.

---

## Проверка модуля

Все пути даны от каталога модуля.

```bash
sudo ./run.sh                 # сводка: консоль, меню GRUB, параметры загрузки, initramfs, SELinux, пароль root
sudo ./scripts/qa/run-module.sh 04-boot-interrupt-rd-break   # prepare → verify → cleanup (из корня rhel-labs)
```

Остановку загрузки изнутри работающей системы проверить нельзя, поэтому `verify.sh`
отвечает на два вопроса: готов ли стенд к занятию и в порядке ли система после него. Он
проверяет, что ядро пишет в последовательный порт, что меню GRUB выводится в консоль и
ждёт, что в initramfs есть `sulogin`, что в записях и шаблонах нет `rd.break`/`enforcing`,
что нет ожидающего `/.autorelabel`, что SELinux в Enforcing и метка `/etc/shadow`
соответствует политике.

```text
[OK] меню GRUB выводится в последовательный порт и ждёт 5 с
[OK] в initramfs ядра по умолчанию есть всё для оболочки rd.break: sulogin, dracut-emergency, chroot, mount
[OK] внутри initramfs у root пустой пароль: оболочка rd.break не спрашивает пароль установленной системы
[OK] метка /etc/shadow соответствует политике: system_u:object_r:shadow_t:s0
[WARN] учётная запись root заблокирована: войти под root в консоли нельзя, задание 03 ещё не выполнено
[OK] module 04-boot-interrupt-rd-break verified
```

`[WARN]` про заблокированный root — норма для чистого стенда: пароль задаёт ученик в
ходе задания, а после занятия ментор возвращает root в заблокированное состояние.

---

## Теоретические вопросы (итоговые)

1. Почему пароль root нельзя сбросить по SSH, а в меню GRUB и через `rd.break` — можно?
2. Чем `rd.break` отличается от `systemd.unit=rescue.target` по тому, чей пароль
   спрашивается?
3. Где в момент оболочки `rd.break` смонтирован корень установленной системы и почему
   его надо перемонтировать перед `passwd`?
4. Что произойдёт при Enforcing, если сбросить пароль и не сделать `touch /.autorelabel`?
5. Чем правка в меню GRUB отличается от `grubby --args` по сроку жизни?
6. Почему `rd.break` нельзя оставлять постоянным параметром на машине без консоли?

Ответы — в `ANSWERS.md`.

---

## Практические задания (отработка)

Задания в формате экзамена — в `tasks/`:

- `tasks/01-reset-root-password.md` — прервать загрузку и сбросить пароль root.
- `tasks/02-one-time-parameter.md` — разовая правка параметра в меню и доказательство,
  что она не пережила перезагрузку.
- `tasks/03-clean-boot-config.md` — убрать из записей параметр, оставленный в
  конфигурации, и вернуть штатную загрузку.

---

## Шпаргалка

```text
# прервать загрузку и получить оболочку
меню GRUB -> e -> на строку linux -> Ctrl+e -> " rd.break" -> Ctrl+x
Press Enter for maintenance -> Enter

# сброс пароля root
mount -o remount,rw /sysroot
chroot /sysroot
passwd
touch /.autorelabel
exit
exit

# проверка после перезагрузки
ls /.autorelabel            # нет
ls -Z /etc/shadow           # shadow_t
getenforce                  # Enforcing
passwd -S root              # root P ...

# запасной путь без полной перемаркировки
меню GRUB: добавить  rd.break enforcing=0
... chroot, passwd, exit, exit ...
после входа:  restorecon -v /etc/shadow ; setenforce 1 ; getenforce

# убрать параметр, случайно оставленный в записях
grubby --update-kernel=ALL --remove-args="rd.break enforcing"
```

---

## Чему вы научились

- Подключаться к машине без обычного входа через последовательную консоль и понимать,
  почему SSH здесь не помогает.
- Останавливать загрузку в меню GRUB и править командную строку ядра на одну загрузку.
- Параметром `rd.break` получать оболочку до запуска установленной системы и понимать,
  чем это отличается от аварийных целей systemd.
- Сбрасывать пароль root через `chroot /sysroot` и `passwd`, не зная старого пароля.
- Понимать роль `/.autorelabel`: почему без него при Enforcing вход потом не работает и
  как чинить метку `/etc/shadow` через `restorecon`.
- Доводить настройку до состояния, переживающего перезагрузку, и убирать из загрузчика
  разовые параметры, случайно ставшие постоянными.

---

## Уборка

После занятия ментор возвращает стенд в исходное состояние:

```bash
sudo ./verify/cleanup.sh           # убирает параметры лабы из записей; ничего не удаляет
sudo passwd -l root                # вернуть root в заблокированное состояние (решает ментор)
sudo systemctl reboot
```

`cleanup.sh` без ключей убирает из записей и шаблонов `rd.break`/`enforcing`, если они
там остались, и сообщает состояние пароля root и метки `/etc/shadow`. Пароль root он не
трогает: заблокировать его обратно — отдельное решение ментора. Настройку GRUB для
консоли (`GRUB_TIMEOUT`, serial) `cleanup.sh` оставляет: это подготовка стенда, а не
след занятия.
