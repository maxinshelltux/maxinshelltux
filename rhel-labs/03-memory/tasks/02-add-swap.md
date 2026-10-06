# 02 — Добавить системе swap на новом разделе

## Цель экзамена
EX200 (RHEL 10), раздел *Configure local storage*:
**Add new partitions and logical volumes, and swap to a system non-destructively**.
Попутно: **List, create, and delete partitions on GPT disks** и **Configure systems
to mount file systems at boot by universally unique ID (UUID) or label** (тот же
раздел), **Boot, reboot, and shut down a system normally** (*Operate running
systems*).

## Задача
В системе нет swap. На одном из двух пустых дисков по 5 ГиБ:

1. Создайте таблицу разделов GPT и раздел размером 1 ГиБ с именем `labswap`.
   Существующие разделы и данные затрагивать нельзя.
2. Сделайте раздел областью подкачки и подключите её.
3. Настройте систему так, чтобы swap подключался при каждой загрузке без вашего
   участия. Раздел укажите по UUID.
4. Перезагрузитесь и докажите результат.

## Проверка
```bash
# до перезагрузки
lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL
tail -n 1 /etc/fstab
findmnt --verify
swapon --show
free -h

systemctl reboot

# после перезагрузки
swapon --show
free -h
```

## Ожидаемый результат
До перезагрузки (строки про диск со swap и последние три команды):
```
nvme1n1       5G disk        
└─nvme1n1p1   1G part swap   labswap

UUID=53a00af0-b460-4ed0-a2a0-4ec3b686ee94 none swap defaults 0 0

Success, no errors or warnings detected

NAME           TYPE       SIZE USED PRIO
/dev/nvme1n1p1 partition 1024M   0B   -2

               total        used        free      shared  buff/cache   available
Mem:           1.6Gi       404Mi       899Mi       7.9Mi       492Mi       1.2Gi
Swap:          1.0Gi          0B       1.0Gi
```
После перезагрузки:
```
NAME           TYPE       SIZE USED PRIO
/dev/nvme0n1p1 partition 1024M   0B   -2

               total        used        free      shared  buff/cache   available
Mem:           1.6Gi       240Mi       1.2Gi       6.5Mi       217Mi       1.4Gi
Swap:          1.0Gi          0B       1.0Gi
```
(имена устройств и UUID у вас свои). Swap на месте, хотя имя раздела после
перезагрузки другое: на стенде он был `nvme1n1p1` при создании и `nvme0n1p1` после
перезагрузки. Строка в `/etc/fstab` написана по UUID, поэтому это не помешало.

Решение (имя диска возьмите из `lsblk` — на стенде оно меняется между
перезагрузками):
```bash
parted -s /dev/nvme1n1 mklabel gpt
parted -s /dev/nvme1n1 mkpart labswap linux-swap 1MiB 1025MiB
udevadm settle
mkswap /dev/nvme1n1p1
blkid /dev/nvme1n1p1
echo 'UUID=<uuid из blkid> none swap defaults 0 0' >> /etc/fstab
systemctl daemon-reload
swapon -a
systemctl reboot
```
`findmnt --verify` отвечает `Success` только после `systemctl daemon-reload`; до него
он предупреждает, что systemd пользуется старой версией `fstab`. Разбор — README,
часть 6.
