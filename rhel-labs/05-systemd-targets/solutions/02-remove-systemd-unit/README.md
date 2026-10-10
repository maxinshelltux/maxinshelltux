# Решение сценария 02: systemd.unit= застрял в записях загрузчика

Инцидент: `broken/scenario-02/`. Параметр `systemd.unit=rescue.target` остался во всех
записях загрузчика и перекрывает target по умолчанию — система каждый раз грузится в
rescue, хотя `get-default` показывает `multi-user.target`.

`fix.sh` убирает его тем же `grubby`, что и в лабе 01:

```bash
sudo ./solutions/02-remove-systemd-unit/fix.sh
# до: systemd.unit= найден в: 6.12.0-211.53.1.el10_2.x86_64 6.12.0-211.61.1.el10_2.x86_64 6.12.0-211.62.1.el10_2.x86_64
# после: systemd.unit= нигде не найден
# [OK] systemd.unit= убран из всех записей
# осталось перезагрузиться и проверить: cat /proc/cmdline | tr ' ' '\n' | grep systemd.unit
```

Вручную: `grubby --update-kernel=ALL --remove-args="systemd.unit"`.

После перезагрузки `/proc/cmdline` не должен содержать `systemd.unit`, а система —
прийти в `multi-user.target`. Записи загрузчика `--remove-args` возвращает к исходному
виду. Если вы заперты (машина ушла в rescue, root заблокирован), сначала получите доступ
с консоли через `rd.break` (лаба `04-boot-interrupt-rd-break`), затем выполните
`grubby --remove-args` из рабочей системы.
