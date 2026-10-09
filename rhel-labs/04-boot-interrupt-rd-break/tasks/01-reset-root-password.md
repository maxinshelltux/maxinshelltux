# 01 — Прервать загрузку и сбросить пароль root

## Цель экзамена
EX200 (RHEL 10), раздел *Operate running systems*:
**Interrupt the boot process in order to gain access to a system**. Сам сброс пароля —
цель **Change passwords and adjust password aging for local user accounts** (*Manage
users and groups*), возврат в Enforcing с правильной меткой — **Restore default file
contexts** и **List and identify SELinux file and process context** (*Manage security*).

## Задача
Пароль root неизвестен, обычного входа под root нет.

1. Прервите загрузку и получите оболочку до запуска установленной системы.
2. Задайте новый пароль root.
3. Сделайте так, чтобы после перезагрузки система сама дошла до входа, SELinux остался
   в Enforcing, а вход под root с новым паролем работал.

Пароль выбираете сами. Нигде его не записывайте.

## Проверка
```bash
# в оболочке rd.break
cat /proc/cmdline | tr ' ' '\n' | grep rd.break

# после всей процедуры и перезагрузки, на загруженной системе
ls /.autorelabel
ls -Z /etc/shadow
getenforce
passwd -S root
```

## Ожидаемый результат
В оболочке `rd.break`:
```
rd.break
```
После перезагрузки:
```
ls: cannot access '/.autorelabel': No such file or directory
system_u:object_r:shadow_t:s0 /etc/shadow
Enforcing
root P 2026-10-09 0 99999 7 -1
```
(дата и поля старения — свои). Статус `P` — пароль задан; до задания был `L`.

Решение целиком — README, части 2–4. Короткая последовательность:
```text
меню GRUB -> e -> строка linux -> Ctrl+e -> " rd.break" -> Ctrl+x
Enter
mount -o remount,rw /sysroot
chroot /sysroot
passwd
touch /.autorelabel
exit
exit
```
Без `touch /.autorelabel` при Enforcing вход потом не работает — см. `broken/scenario-01`.
