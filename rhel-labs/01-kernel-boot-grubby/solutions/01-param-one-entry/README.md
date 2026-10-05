# Решение сценария 01: параметр только в одной записи

Инцидент: `broken/scenario-01/`. Параметр `transparent_hugepage=never` задан записи
одного ядра, а по умолчанию грузится другое.

`fix.sh` выполняет официальную команду для всех записей и проверяет результат:

```bash
grubby --update-kernel=ALL --args="transparent_hugepage=never"
```

После него нужна перезагрузка, затем проверка `cat /proc/cmdline` и
`cat /sys/kernel/mm/transparent_hugepage/enabled`.
