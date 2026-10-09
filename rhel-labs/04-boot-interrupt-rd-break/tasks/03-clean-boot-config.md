# 03 — Убрать параметр, оставшийся в записях загрузчика

## Цель экзамена
EX200 (RHEL 10), раздел *Deploy, configure, and maintain systems*:
**Modify the system bootloader**. Применение и проверка — **Boot, reboot, and shut down
a system normally** (*Operate running systems*).

## Задача
На системе в записях загрузчика остался параметр из восстановления — он не должен был
стать постоянным.

1. Найдите, в каких записях и шаблонах присутствует `enforcing=0`.
2. Уберите его из всех записей штатным инструментом.
3. Перезагрузитесь и докажите, что SELinux снова в Enforcing, а параметра в
   `/proc/cmdline` нет.

## Проверка
```bash
# до
grubby --info=ALL | grep -o 'enforcing=0'
cat /etc/kernel/cmdline | tr ' ' '\n' | grep enforcing

# действие
sudo grubby --update-kernel=ALL --remove-args="enforcing"

# после перезагрузки
getenforce
cat /proc/cmdline | tr ' ' '\n' | grep enforcing || echo "в /proc/cmdline нет"
grubby --info=ALL | grep -o 'enforcing=0' || echo "в записях нет"
```

## Ожидаемый результат
После удаления и перезагрузки:
```
Enforcing
в /proc/cmdline нет
в записях нет
```
Инструмент — `grubby` из лабы 01: `--update-kernel=ALL --remove-args` убирает параметр
из всех записей и шаблонов. Почему `enforcing=0` вообще опасно оставлять — README,
часть 5, инцидент 2.
