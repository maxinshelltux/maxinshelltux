# 01 — Параметр ядра для всех установленных ядер

## Цель экзамена
EX200 (RHEL 10), раздел *Deploy, configure, and maintain systems*:
**Modify the system bootloader**. Применение настройки — цель
**Boot, reboot, and shut down a system normally** (*Operate running systems*).

## Задача
Настройте систему так, чтобы **все** установленные ядра загружались с параметром
`transparent_hugepage=never`. Настройка должна действовать после перезагрузки без
вашего участия и доставаться ядрам, которые установят позже.

## Проверка
```bash
# до перезагрузки: параметр во всех записях и в шаблоне для будущих ядер
grubby --info=ALL | grep -E '^(index|args)='
cat /etc/kernel/cmdline

systemctl reboot

# после перезагрузки: параметр получен ядром и исполнен
cat /proc/cmdline
cat /sys/kernel/mm/transparent_hugepage/enabled
```

## Ожидаемый результат
```
index=0
args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=never"
index=1
args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=never"

root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 transparent_hugepage=never
```
После перезагрузки:
```
BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M transparent_hugepage=never

always madvise [never]
```
(версии, UUID и остальные параметры у вас свои). Параметр стоит в **каждой** записи,
есть в `/etc/kernel/cmdline` и в `/proc/cmdline`, а квадратные скобки в sysfs
перешли на `never`.

Решение — одна команда: `grubby --update-kernel=ALL --args="transparent_hugepage=never"`
и перезагрузка. Разбор — README, часть 2.
