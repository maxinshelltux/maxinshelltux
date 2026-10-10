# Решение сценария 01: target по умолчанию сброшен в rescue.target

Инцидент: `broken/scenario-01/`. `systemctl get-default` показывает `rescue.target`,
из-за чего система каждый раз загружается в rescue без сети и SSH.

`fix.sh` возвращает значение по умолчанию на `multi-user.target`:

```bash
sudo ./solutions/01-default-target/fix.sh
# до: target по умолчанию rescue.target
# проблема: target по умолчанию rescue.target, в исходном образе multi-user.target
# после: target по умолчанию multi-user.target
# [OK] target по умолчанию возвращён на multi-user.target
# осталось перезагрузиться и проверить: systemctl get-default
```

Вручную то же самое:

```bash
sudo systemctl set-default multi-user.target
sudo systemctl reboot
```

После перезагрузки `systemctl get-default` должен показать `multi-user.target`, а SSH —
снова работать. Если вы уже заперты (машина в rescue, root заблокирован), сначала
получите доступ с консоли — это соседняя лаба `04-boot-interrupt-rd-break` (`rd.break`),
а затем выполните `set-default` из рабочей системы.
