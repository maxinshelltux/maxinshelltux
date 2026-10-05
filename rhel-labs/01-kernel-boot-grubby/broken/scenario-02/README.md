# Сценарий 02: «поставили обновление ядра, а грузится старое»

Цель экзамена: EX200 (RHEL 10) — **Modify the system bootloader**.

## Симптом
После обновления ядра и перезагрузки `uname -r` показывает старую версию. Автор
заявки говорит, что перед перезагрузкой сам выбрал запись по индексу — самую новую,
как ему казалось.
```bash
sudo ./broken/scenario-02/make-broken.sh
# Что сделал автор заявки:
# # grubby --set-default-index=0
# The default is /boot/loader/entries/ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64.conf with index 0 and kernel /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64

sudo systemctl reboot
# после входа:
uname -r
# 6.12.0-211.53.1.el10_2.x86_64
rpm -q kernel
# kernel-6.12.0-211.53.1.el10_2.x86_64
# kernel-6.12.0-211.61.1.el10_2.x86_64
```
Новое ядро установлено, но работает старое.

## Подсказки
1. Что отвечает `grubby --default-kernel`? Совпадает ли это с `uname -r`?
2. Какой индекс у какого ядра? Посмотрите `grubby --info=ALL`, а не угадывайте.
3. Прочитайте, что `grubby` напечатал в ответ на `--set-default-index=0`.

## Диагностика
```bash
grubby --default-kernel
# /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64
grubby --default-index
# 0
grub2-editenv list
# saved_entry=ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64
# boot_success=1

grubby --info=ALL | grep -E '^(index|kernel)='
# index=0
# kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
# index=1
# kernel="/boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64"

ls -1 /boot/loader/entries/
# ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64.conf
# ffffffffffffffffffffffffffffffff-6.12.0-211.53.1.el10_2.x86_64.conf

cat /etc/sysconfig/kernel
# UPDATEDEFAULT=yes
# DEFAULTKERNEL=kernel
```
Система сделала ровно то, что ей сказали: по умолчанию выбрана запись 0, а запись 0
на этом стенде — старое ядро. Обновление здесь ни при чём: `UPDATEDEFAULT=yes`, и
сразу после установки новое ядро было ядром по умолчанию; выбор перебила ручная
команда.

Почему индекс 0 не самое новое ядро: `grubby` нумерует записи по именам файлов после
`sort -Vr` (скрипт `/usr/sbin/grubby`, строки 88–95 в версии 8.40-83.el10). Имя
старой записи начинается с `ffff…`, новой — с настоящего machine-id `ec2e861e…`,
поэтому `ffff…` идёт первой. Документация RHEL 10 (раздел 1.8) предупреждает, что
установка ядер может менять значения индексов.

## Решение
Задать ядро по умолчанию **путём** (см. `solutions/02-default-pinned/fix.sh`):
```bash
sudo ./solutions/02-default-pinned/fix.sh
# до исправления: по умолчанию /boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64 (index 0)
# The default is /boot/loader/entries/ec2e861e25a5b84dae694a5a8a2360fc-6.12.0-211.61.1.el10_2.x86_64.conf with index 1 and kernel /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64
# [OK] по умолчанию самое новое ядро: /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64 (index 1)

sudo systemctl reboot
# после входа:
uname -r
# 6.12.0-211.61.1.el10_2.x86_64
```
Вручную то же самое: `grubby --set-default /boot/vmlinuz-6.12.0-211.61.1.el10_2.x86_64`.

## Урок
`grubby --set-default` и `--set-default-index` печатают, какую запись и какое ядро
они выбрали, — читайте эту строку. Ядро задавайте путём; индекс допустим только
после `grubby --info=ALL`.

После разбора стенд уже в порядке; для уверенности — `sudo ./verify/cleanup.sh`.
