# 02 — Заменить значение, задать параметр одной записи, убрать лишнее

## Цель экзамена
EX200 (RHEL 10), раздел *Deploy, configure, and maintain systems*:
**Modify the system bootloader**. Применение настройки — цель
**Boot, reboot, and shut down a system normally** (*Operate running systems*).

## Задача
Исходное состояние — результат задания 01 (`transparent_hugepage=never` у всех ядер).

1. Измените значение параметра на `transparent_hugepage=madvise` для всех ядер. В
   записях не должно остаться старого значения.
2. Добавьте параметр `quiet` **только** записи ядра, которое сейчас работает.
3. Перезагрузитесь и докажите, что оба изменения действуют.
4. Уберите `transparent_hugepage` и `quiet` из всех записей, перезагрузитесь и
   докажите, что система вернулась к исходным параметрам.

## Проверка
```bash
# после шагов 1–2
grubby --info=ALL | grep -E '^(index|args)='

# после перезагрузки (шаг 3)
cat /proc/cmdline
cat /sys/kernel/mm/transparent_hugepage/enabled

# после шага 4, до перезагрузки
grubby --info=ALL | grep -E '^(index|args)='
cat /etc/kernel/cmdline

# после второй перезагрузки
cat /proc/cmdline
cat /sys/kernel/mm/transparent_hugepage/enabled
```

## Ожидаемый результат
После шагов 1–2 (на стенде работает ядро с индексом 1):
```
index=0
args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=madvise"
index=1
args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=madvise quiet"
```
После перезагрузки:
```
BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M transparent_hugepage=madvise quiet

always [madvise] never
```
После шага 4:
```
index=0
args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params"
index=1
args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params"

root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295
```
После второй перезагрузки:
```
BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M

[always] madvise never
```
Значение заменено без дубля, `quiet` есть только в одной записи, а после уборки
параметров нет ни в записях, ни в шаблоне, ни в работающей системе.

Решение:
```bash
grubby --update-kernel=ALL --args="transparent_hugepage=madvise"
grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="quiet"
systemctl reboot
grubby --update-kernel=ALL --remove-args="transparent_hugepage quiet"
systemctl reboot
```
Разбор — README, части 2.3 и 3.
