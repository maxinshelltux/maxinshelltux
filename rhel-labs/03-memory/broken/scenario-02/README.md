# Сценарий 02: «swap добавили, а после перезагрузки его нет»

Цели EX200 (RHEL 10): **Add new partitions and logical volumes, and swap to a system
non-destructively** и **Configure systems to mount file systems at boot by
universally unique ID (UUID) or label**.

Сценарию нужен раздел `labswap` из части 6 README (или задания `tasks/02`).

## Симптом
Swap добавлен и работает. После перезагрузки его нет, хотя раздел на месте.
```bash
sudo ./broken/scenario-02/make-broken.sh
# Заявка: «Добавил серверу swap, проверил — работает. После перезагрузки
# swap пропал, хотя раздел на месте».
#
# Что видит автор заявки до перезагрузки:
# # swapon --show
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme0n1p1 partition 1024M   0B   -2
# # free -m | tail -n 1
# Swap:           1023           0        1023

sudo systemctl reboot
# после входа:
swapon --show
# (пусто)
free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         241        1223           6         215        1405
# Swap:              0           0           0
```

## Подсказки
1. Раздел никуда не делся. Что именно пропало?
2. Какая команда включала swap и что она меняет на диске?
3. Откуда система при загрузке узнаёт, какие области подкачки подключать?

## Диагностика
```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,UUID
# NAME         SIZE TYPE FSTYPE PARTLABEL UUID
# nvme0n1        5G disk                  
# └─nvme0n1p1    1G part swap   labswap   53a00af0-b460-4ed0-a2a0-4ec3b686ee94
# nvme1n1        5G disk                  
# nvme2n1       20G disk                  
# ├─nvme2n1p1    1M part                  
# ├─nvme2n1p2  200M part vfat             97D2-64D3
# └─nvme2n1p3 19.8G part xfs              c78c1f15-7ec8-4bc4-b1b6-0e557f828ec1

grep swap /etc/fstab
# (пусто, код возврата 1)
```
Раздел цел, сигнатура swap и UUID на месте. А в `/etc/fstab` про него ни строки:
swap включили командой `swapon`, которая действует до перезагрузки. При загрузке
система подключает только то, что описано в `/etc/fstab`.

`./run.sh` предупреждал об этом ещё до перезагрузки:
```text
[WARN] swap /dev/nvme0n1p1 подключён сейчас, но строки в /etc/fstab нет — после перезагрузки пропадёт
```

## Решение
Прописать раздел в `/etc/fstab` по UUID и проверить строку тем же способом, каким её
применит загрузка (см. `solutions/02-swap-not-persistent/fix.sh`):
```bash
sudo ./solutions/02-swap-not-persistent/fix.sh
# до исправления: swap на /dev/nvme0n1p1 подключён: нет, строка в /etc/fstab: нет
# 3:UUID=53a00af0-b460-4ed0-a2a0-4ec3b686ee94 none swap defaults 0 0
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme0n1p1 partition 1024M   0B   -2
# [OK] swap прописан в /etc/fstab по UUID и подключён
# осталось перезагрузиться и проверить: swapon --show; free -m

sudo systemctl reboot
# после входа:
swapon --show
# NAME           TYPE       SIZE USED PRIO
# /dev/nvme1n1p1 partition 1024M   0B   -2
free -h
#                total        used        free      shared  buff/cache   available
# Mem:           1.6Gi       278Mi       1.2Gi       6.5Mi       212Mi       1.3Gi
# Swap:          1.0Gi          0B       1.0Gi
```
Swap пережил перезагрузку. Имя раздела при этом сменилось с `nvme0n1p1` на
`nvme1n1p1` — на этом стенде так бывает, и именно поэтому в `/etc/fstab` пишут UUID.

Вручную то же самое:
```bash
blkid /dev/<раздел>
echo 'UUID=<uuid> none swap defaults 0 0' >> /etc/fstab
systemctl daemon-reload
swapon -a
```

## Урок
`swapon` — на сеанс, `/etc/fstab` — навсегда. После любой правки `/etc/fstab`
проверяйте её до перезагрузки: `findmnt --verify` и `swapon -a`.

После разбора верните стенд: `sudo ./verify/cleanup.sh`; раздел удаляет запуск с
ключом `--apply`.
