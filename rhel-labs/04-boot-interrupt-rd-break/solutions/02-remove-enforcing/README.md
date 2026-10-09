# Решение сценария 02: enforcing=0 в записях загрузчика

Инцидент: `broken/scenario-02/`. Параметр `enforcing=0` остался во всех записях и в
шаблоне, из-за чего система грузится в permissive.

`fix.sh` убирает его тем же `grubby`, что и в лабе 01:

```bash
sudo ./solutions/02-remove-enforcing/fix.sh
# до: enforcing=0 в записях: 3, в шаблоне: да
# The default is ... (grubby печатает запись)
# после: enforcing=0 в записях: 0, в шаблоне: нет
# [OK] enforcing=0 убран из всех записей и шаблона
# осталось перезагрузиться и проверить: getenforce
```

Вручную: `grubby --update-kernel=ALL --remove-args="enforcing"`.

После перезагрузки `getenforce` должен показать `Enforcing`, а `/proc/cmdline` — не
содержать `enforcing`. Записи загрузчика `--remove-args` возвращает к исходному виду
(их содержимое совпадает с состоянием до `--args`).
