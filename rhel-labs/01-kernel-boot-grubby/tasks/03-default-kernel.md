# 03 — Ядро по умолчанию

## Цель экзамена
EX200 (RHEL 10), раздел *Deploy, configure, and maintain systems*:
**Modify the system bootloader**. Применение настройки — цель
**Boot, reboot, and shut down a system normally** (*Operate running systems*).
Второе ядро на стенде появляется по цели **Install and update software packages from
Red Hat Content Delivery Network, a remote repository, or from the local file system**
(`dnf upgrade kernel`).

## Задача
На системе установлено два ядра.

1. Определите, какое ядро загрузится при следующей перезагрузке.
2. Сделайте ядром по умолчанию **самое старое** из установленных. После
   перезагрузки система должна работать на нём без вашего участия.
3. Верните по умолчанию самое новое ядро и перезагрузитесь.

## Проверка
```bash
# шаг 1
grubby --default-kernel
grubby --info=ALL | grep -E '^(index|kernel|title)='

# после шага 2, до перезагрузки
grubby --default-kernel
grub2-editenv list
uname -r

# после перезагрузки
uname -r

# после шага 3 и второй перезагрузки
grubby --default-kernel
uname -r
```

## Ожидаемый результат
Шаг 1:
```
/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

index=0
kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
title="Red Hat Enterprise Linux (6.12.0-211.53.1.el10_2.x86_64) 10.2 (Coughlan)"
index=1
kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
title="Red Hat Enterprise Linux (6.12.0-211.61.1.el10_2.x86_64) 10.2 (Coughlan)"
```
После шага 2, до перезагрузки:
```
/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64

saved_entry=ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64
boot_success=1

6.12.0-211.61.1.el10_2.x86_64        <- работает ещё прежнее ядро
```
После перезагрузки:
```
6.12.0-211.53.1.el10_2.x86_64
```
После шага 3 и второй перезагрузки:
```
/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
6.12.0-211.61.1.el10_2.x86_64
```
(версии и идентификаторы у вас свои). Важно, что `uname -r` после каждой
перезагрузки совпадает с тем, что перед ней показывал `grubby --default-kernel`.

Решение:
```bash
grubby --set-default /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64
systemctl reboot
grubby --set-default /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
systemctl reboot
```
Задавайте ядро путём. Индекс 0 на этом стенде — старое ядро, а не новое; почему —
README, часть 4.4.
