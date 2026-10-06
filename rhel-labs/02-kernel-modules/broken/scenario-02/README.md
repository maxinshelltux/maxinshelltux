# Сценарий 02: «модуль в автозагрузке, а после старта его нет»

Цели EX200 (RHEL 10), на которые опирается разбор: **Locate and interpret system log
files and journals** и **Start and stop services and configure services to start
automatically at boot**. Отдельной цели про модули ядра в списке нет.

## Симптом
Модуль `dummy` прописан в `/etc/modules-load.d/dummy.conf`, но после старта не
загружен. Руками `modprobe dummy` загружает его без ошибок.
```bash
sudo ./broken/scenario-02/make-broken.sh
# Заявка: «Прописал dummy в автозагрузку, а после перезагрузки модуля нет.
# При этом руками modprobe dummy отрабатывает без единой ошибки».
#
# Что видит автор заявки:
# # cat /etc/modules-load.d/dummy.conf
# dummy
# # systemctl is-active systemd-modules-load.service
# active
# # lsmod | grep dummy
# (пусто)
```
Служба автозагрузки `active`, файл правильный, модуля нет.

## Подсказки
1. Служба отработала без ошибки. А что она написала в журнал?
2. Чем загрузка службой отличается от загрузки командой `modprobe dummy`?
3. Где, кроме `/etc/modules-load.d`, может быть сказано что-то про `dummy`?

## Диагностика
```bash
journalctl -b -u systemd-modules-load.service --no-pager -o cat | tail -n 4
# Starting systemd-modules-load.service - Load Kernel Modules...
# Module 'dummy' is deny-listed (by kmod)
# Module 'msr' is built in
# Finished systemd-modules-load.service - Load Kernel Modules.

modprobe -c | grep -E "^(options|blacklist|install) dummy"
# blacklist dummy
# options dummy numdummies=0

grep -rnE "^(blacklist|install) dummy" /etc/modprobe.d/ /usr/lib/modprobe.d/ /run/modprobe.d/
# /etc/modprobe.d/lab-denylist.conf:1:blacklist dummy

modprobe dummy; lsmod | grep dummy; modprobe -r dummy
# dummy                  12288  0
```
Модуль стоит в списке запрета. Служба автозагрузки запрет учитывает и модуль
пропускает — молча, без ошибки, запись есть только в журнале. Явный `modprobe dummy`
строку `blacklist` не учитывает, поэтому руками всё работает и сбивает с толку.

`./run.sh` говорит то же:
```text
[WARN] dummy указан в автозагрузке (/etc/modules-load.d/dummy.conf), но запрещён — загружен не будет
```

## Решение
Убрать строку запрета (см. `solutions/02-denylisted-autoload/fix.sh`):
```bash
sudo ./solutions/02-denylisted-autoload/fix.sh
# до исправления: dummy загружен: нет
# что запрещает загрузку:
# /etc/modprobe.d/lab-denylist.conf:1:blacklist dummy
# dummy                  12288  0
# [OK] запрет снят, dummy загружен службой автозагрузки
# осталось перезагрузиться и проверить: lsmod | grep dummy
```
Скрипт удаляет из `/etc/modprobe.d/lab-denylist.conf` строки про `dummy` (сам файл
остаётся) и перезапускает службу автозагрузки.

## Урок
`active` у `systemd-modules-load.service` не значит, что все модули загружены.
Смотрите журнал службы и `modprobe -c`.

После разбора верните стенд: `sudo ./verify/cleanup.sh`, а файлы удаляет запуск с
ключом `--apply`.
