# Сценарий 02: «SELinux сам стал permissive»

Цель экзамена: EX200 (RHEL 10) — **Set enforcing and permissive modes for SELinux**
(*Manage security*) и **Modify the system bootloader** (*Deploy, configure, and maintain
systems*).

## Симптом
После восстановления системы кто-то заметил, что SELinux работает в permissive, хотя в
конфигурации стоит enforcing. Это тихая регрессия безопасности: политика не применяется.

```bash
sudo ./broken/scenario-02/make-broken.sh

# после перезагрузки
getenforce
# Permissive
grep ^SELINUX= /etc/selinux/config
# SELINUX=enforcing
```

`/etc/selinux/config` требует enforcing, а система в permissive — значит, режим
переопределён на уровне загрузки.

## Диагностика
```bash
cat /proc/cmdline | tr ' ' '\n' | grep enforcing
# enforcing=0

grubby --info=DEFAULT | grep -o 'enforcing=0'
# enforcing=0

grubby --info=ALL | grep -c 'enforcing=0'
# 3

grep -o 'enforcing=0' /etc/kernel/cmdline
# enforcing=0
```
`enforcing=0` в командной строке ядра переводит SELinux в permissive при загрузке и
имеет приоритет над `/etc/selinux/config`. Параметр попал во все записи и в шаблон —
значит, его добавили через `grubby --args ... ALL` (запасной путь из части 4), а убрать
забыли. Новые ядра его тоже унаследуют.

## Причина
Запасной способ сброса пароля (RHEL 8, часть 4) использует разовую загрузку с
`enforcing=0`. Если вместо разовой правки в меню параметр прописали в записи через
`grubby`, он остаётся постоянным.

## Решение
Разбор — `solutions/02-remove-enforcing/`. Убрать параметр штатным инструментом и
перезагрузиться:
```bash
sudo grubby --update-kernel=ALL --remove-args="enforcing"
sudo grubby --info=DEFAULT | grep -o 'enforcing=0' || echo "в записи нет"
# в записи нет

sudo systemctl reboot
# после входа:
getenforce
# Enforcing
```

## Урок
`enforcing=0` хорош для разовой загрузки через меню GRUB, но в записи загрузчика это
постоянный перевод системы в permissive. Проверяйте `getenforce` против
`/etc/selinux/config`; расхождение почти всегда означает параметр в командной строке
ядра. Убирают его тем же `grubby`, что и в лабе 01.

После разбора стенд уже в порядке; для уверенности — `sudo ./verify/cleanup.sh`.
