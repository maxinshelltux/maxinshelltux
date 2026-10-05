# Сценарий 01: «параметр задан через grubby, а после перезагрузки его нет»

Цель экзамена: EX200 (RHEL 10) — **Modify the system bootloader**.

## Симптом
Коллега добавил `transparent_hugepage=never`, перезагрузил сервер — а THP всё ещё
включён. При этом `grubby` параметр показывает.
```bash
sudo ./broken/scenario-01/make-broken.sh
# Заявка: «Добавил transparent_hugepage=never через grubby, перезагрузил сервер —
# а THP всё ещё включён. grubby показывает, что параметр на месте».
#
# Что видит автор заявки:
# # grubby --info=ALL | grep -c transparent_hugepage=never
# 1

sudo systemctl reboot
# после входа:
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M
cat /sys/kernel/mm/transparent_hugepage/enabled
# [always] madvise never
```

## Подсказки
1. `grep -c` ответил `1`. А сколько на машине записей загрузчика?
2. Какая запись загрузилась? Сравните `uname -r` с `grubby --default-kernel`.
3. Чем `--update-kernel=<путь>` отличается от `--update-kernel=ALL`?

## Диагностика
```bash
grubby --info=ALL | grep -E '^(index|kernel|args)='
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params transparent_hugepage=never"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
# args="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 crashkernel=2G-64G:256M,64G-:512M $tuned_params"

grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

cat /etc/kernel/cmdline
# root=UUID=c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1 console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295
```
Параметр есть только у записи ядра `…53.1`, а по умолчанию грузится `…61.1`.
Автор заявки правил одну запись по пути и проверял `grep` по всему выводу: строка
нашлась, но не в той записи. Второй признак — в `/etc/kernel/cmdline` параметра
нет, значит через `ALL` его не задавали.

## Решение
Задать параметр всем записям (см. `solutions/01-param-one-entry/fix.sh`):
```bash
sudo ./solutions/01-param-one-entry/fix.sh
# до исправления: записей с параметром 1 из 2
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# args="... $tuned_params transparent_hugepage=never"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"
# args="... $tuned_params transparent_hugepage=never"
# [OK] transparent_hugepage=never во всех записях, включая запись по умолчанию /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64

sudo systemctl reboot
# после входа:
cat /proc/cmdline
# BOOT_IMAGE=(hd0,gpt3)/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 root=UUID=... crashkernel=2G-64G:256M,64G-:512M transparent_hugepage=never
cat /sys/kernel/mm/transparent_hugepage/enabled
# always madvise [never]
```

## Урок
Проверяйте не «есть ли строка в выводе grubby», а «есть ли параметр в записи,
которая грузится»: `grubby --info=DEFAULT`. Если в задании сказано «для всех ядер»
или не сказано ничего — используйте `ALL`.

После разбора верните стенд: `sudo ./verify/cleanup.sh` и перезагрузка.
