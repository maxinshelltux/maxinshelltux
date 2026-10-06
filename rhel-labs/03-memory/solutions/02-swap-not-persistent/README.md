# Решение сценария 02: swap подключён, но не прописан

Инцидент: `broken/scenario-02/`. Swap включён командой `swapon`, строки в
`/etc/fstab` нет, поэтому после перезагрузки его не будет.

`fix.sh` берёт UUID раздела `labswap`, добавляет строку в `/etc/fstab`, если её ещё
нет, и проверяет её тем же способом, что и загрузка:

```bash
echo 'UUID=<uuid> none swap defaults 0 0' >> /etc/fstab
systemctl daemon-reload
swapon -a
```

Если у раздела нет UUID (на нём нет сигнатуры swap), скрипт останавливается и в
`/etc/fstab` ничего не пишет. После него нужна перезагрузка, затем проверка
`swapon --show` и `free -m`.
