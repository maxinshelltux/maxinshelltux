# 03 — Запретить загрузку модуля

## Цель экзамена
В списке целей EX200 (RHEL 10) отдельной цели про модули ядра нет. Задание опирается
на цели: **Create and edit text files** (*Understand and use essential tools*),
**Locate and interpret system log files and journals** и **Boot, reboot, and shut
down a system normally** (*Operate running systems*).
Команды — из раздела 3.10 руководства RHEL 10 и `man modprobe.d`.

## Задача
Исходное состояние: модуль `dummy` загружается при старте. Если это ещё не так —
`echo dummy > /etc/modules-load.d/dummy.conf`. Параметров модулю не задаём.

1. Запретите загрузку модуля `dummy`: он не должен загружаться ни при старте
   системы, ни командой `modprobe dummy`.
2. Перезагрузитесь и докажите оба утверждения. Найдите в журнале запись о том, что
   служба автозагрузки пропустила модуль.
3. Снимите запрет и убедитесь, что автозагрузка снова работает.

## Проверка
```bash
# после шага 1
modprobe -c | grep -E '^(blacklist|install) dummy'
modprobe --show-depends dummy

# после перезагрузки (шаг 2)
lsmod | grep dummy
modprobe dummy
journalctl -b -t systemd-modules-load --no-pager -o cat | grep dummy

# после шага 3
systemctl restart systemd-modules-load.service
lsmod | grep dummy
```

## Ожидаемый результат
После шага 1:
```
blacklist dummy
install dummy /bin/false

install /bin/false numdummies=0 
```
После перезагрузки (первая команда ничего не печатает):
```
modprobe: ERROR: libkmod/libkmod-module.c:1084 command_do() Error running install command '/bin/false' for module dummy: retcode 1
modprobe: ERROR: could not insert 'dummy': Invalid argument

Module 'dummy' is deny-listed (by kmod)
```
После шага 3:
```
dummy                  12288  0
```

Решение:
```bash
printf 'blacklist dummy\ninstall dummy /bin/false\n' > /etc/modprobe.d/lab-denylist.conf
systemctl reboot
: > /etc/modprobe.d/lab-denylist.conf
systemctl restart systemd-modules-load.service
```
Пересобирать initramfs здесь не нужно: `lsinitrd /boot/initramfs-$(uname -r).img |
grep dummy` ничего не находит. Разбор — README, часть 4.
