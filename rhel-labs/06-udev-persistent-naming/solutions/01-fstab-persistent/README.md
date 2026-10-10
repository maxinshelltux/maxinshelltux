# Решение сценария 01: монтирование по имени ядра в fstab

Инцидент: `broken/scenario-01/`. В `/etc/fstab` попала строка вида
`/dev/nvme1n1 /mnt/labdata xfs defaults 0 0` — монтирование по имени ядра, без `nofail`.
После перезагрузки имя указывает не туда (или на диске нет ФС), монтирование падает, и
система уходит в emergency.

`fix.sh` восстанавливает `/etc/fstab` из снимка, сделанного `make-broken.sh`:

```bash
sudo ./solutions/01-fstab-persistent/fix.sh
# в /etc/fstab монтирование по имени ядра: /dev/nvme1n1
# восстановлен /etc/fstab из снимка /var/lib/rhel-labs/06-udev-persistent-naming/fstab.before-scenario-01
# [OK] в /etc/fstab не осталось монтирования по имени ядра
# (findmnt --verify — без ошибок)
```

Если снимка нет, уберите сбойную строку вручную. Правильный способ смонтировать этот
диск — по UUID и с `nofail` (задание 02):

```bash
sudo mkfs.xfs /dev/nvme1n1
UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1)
echo "UUID=$UUID  /mnt/labdata  xfs  defaults,nofail  0 0" | sudo tee -a /etc/fstab
sudo findmnt --verify
sudo mount -a
```

Если вы уже заперты (система в emergency, root заблокирован) — сначала получите доступ с
консоли через `rd.break` (лаба `04-boot-interrupt-rd-break`), смонтируйте корень на
запись и поправьте `/etc/fstab`, затем перезагрузитесь.
