# Решение сценария 02: модуль в списке запрета

Инцидент: `broken/scenario-02/`. Модуль прописан в автозагрузку, но в
`/etc/modprobe.d/lab-denylist.conf` стоит `blacklist dummy`, и служба автозагрузки
его пропускает.

`fix.sh` показывает, где задан запрет, убирает строки про `dummy` из файла запрета и
перезапускает службу:

```bash
sed -i -E '/^(blacklist dummy|install dummy \/bin\/false)$/d' /etc/modprobe.d/lab-denylist.conf
systemctl restart systemd-modules-load.service
```

После него нужна перезагрузка, затем проверка `lsmod | grep dummy`.
