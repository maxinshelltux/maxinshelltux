# 01 — Найти постоянные имена устройства

## Цель экзамена
EX200 (RHEL 10), раздел *Configure local storage*:
**Configure systems to mount file systems at boot by universally unique ID (UUID) or
label**. Это задание — опора под неё: чтобы монтировать по UUID/label, надо сначала
научиться находить устойчивые идентификаторы устройства.

## Задача
Для запасного диска стенда (диск без файловой системы; найдите его в `lsblk`):

1. Покажите его имя ядра и подтвердите, что оно может меняться между загрузками.
2. Найдите все его постоянные имена в `/dev/disk/*` (`by-id`, `by-path`).
3. Тем же устройством через `udevadm` получите список его симлинков (`DEVLINKS`) и
   серийный номер (`ID_SERIAL_SHORT`).

## Проверка
```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,SERIAL
SPARE=/dev/nvme1n1      # подставьте имя своего запасного диска
ls -l /dev/disk/by-id | grep "$(basename "$SPARE")"
sudo udevadm info --name "$SPARE" --query property --property DEVLINKS --value
sudo udevadm info --name "$SPARE" --query property --property ID_SERIAL_SHORT --value
```

## Ожидаемый результат
```
nvme1n1   5G disk        vol0ed094b9462cbadc2
```
```
nvme-Amazon_Elastic_Block_Store_vol0ed094b9462cbadc2 -> ../../nvme1n1
```
```
/dev/disk/by-path/pci-0000:00:1f.0-nvme-1 /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol0ed094b9462cbadc2 ...
vol0ed094b9462cbadc2
```
(имена и серийники — свои). Имя ядра `nvme1n1` на этом стенде не закреплено за диском: по
`02-kernel-modules` и `03-memory` известно, что `nvme`-имена перетасовываются при
загрузке. А `by-id` (серийный номер EBS) и `by-path` (слот PCI) к диску привязаны. Источник:
RHEL 10, «Managing storage devices», раздел 2.1; `man 8 udevadm`.
