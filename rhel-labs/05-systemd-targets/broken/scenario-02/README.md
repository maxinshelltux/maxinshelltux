# Сценарий 02: «get-default говорит multi-user, а грузится rescue»

Цель экзамена: EX200 (RHEL 10) — **Boot systems into different targets manually**
(*Operate running systems*) и **Modify the system bootloader** (*Deploy, configure, and
maintain systems*).

## Симптом
Машина после перезагрузки уходит в rescue (SSH недоступен), но target по умолчанию
выглядит правильным:

```bash
# с консоли, на загруженной в rescue системе
systemctl get-default
# Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
# multi-user.target
```
`get-default` показывает `multi-user.target` — и всё равно загрузка пришла в rescue.
Подсказка в самой первой строке: `systemd.unit` в командной строке ядра перекрывает
target по умолчанию.

> ВНИМАНИЕ. `make-broken.sh --apply` дописывает `systemd.unit=rescue.target` во все
> записи. После перезагрузки нет сети и SSH; вернуть систему можно только с консоли.
> Запускайте с ментором и при открытой консоли.

```bash
sudo ./broken/scenario-02/make-broken.sh            # покажет, что сделает
sudo ./broken/scenario-02/make-broken.sh --apply    # воспроизвести (после reboot рвёт SSH!)
```

## Диагностика
```bash
cat /proc/cmdline | tr ' ' '\n' | grep systemd.unit
# systemd.unit=rescue.target

grubby --info=ALL | grep -o 'systemd.unit=rescue.target' | head -n 1
# systemd.unit=rescue.target

grubby --info=ALL | grep -c 'systemd.unit='
# 3
```
Параметр `systemd.unit=` в командной строке ядра задаёт target на загрузку и имеет
приоритет над симлинком `default.target`. Он попал во все записи — значит, добавлен
через `grubby --args ... ALL`, а убрать забыли; новые ядра его тоже унаследуют.

## Причина
`systemd.unit=rescue.target` хорош как **разовая** правка в меню GRUB (часть 3): одна
загрузка в rescue и назад. Если тот же параметр прописать в запись через `grubby`, он
становится постоянным и перекрывает `multi-user.target` при каждой загрузке — а
`get-default` по-прежнему честно показывает `multi-user.target`, отсюда путаница.

## Решение
Разбор — `solutions/02-remove-systemd-unit/`. Убрать параметр тем же `grubby`, что и в
лабе 01, и перезагрузиться:

```bash
sudo grubby --update-kernel=ALL --remove-args="systemd.unit"
grubby --info=ALL | grep -c 'systemd.unit=' || echo 0
# 0

sudo systemctl reboot
# после входа:
cat /proc/cmdline | tr ' ' '\n' | grep systemd.unit || echo "в /proc/cmdline нет"
# в /proc/cmdline нет
```

## Урок
Когда `get-default` и реально достигнутый target расходятся — смотрите `/proc/cmdline`:
`systemd.unit=` на командной строке ядра всегда сильнее `default.target`. Разовый вход в
target задают в меню GRUB, а не `grubby --args`; постоянный `systemd.unit=rescue.target`
на машине без консоли — потеря доступа. Убирают его тем же `grubby --remove-args`.

После разбора стенд уже в порядке; для уверенности — `sudo ./verify/cleanup.sh`.
