# 02 — Смонтировать файловую систему по UUID и закрепить в fstab

## Цель экзамена
EX200 (RHEL 10), раздел *Configure local storage*, дословно:
**Configure systems to mount file systems at boot by universally unique ID (UUID) or
label**. Смежно — *Create, mount, unmount, and use VFAT, ext4, and XFS file systems*.

## Задача
На запасном диске стенда (без данных; проверьте в `lsblk`, что он пуст):

1. Создайте на нём файловую систему XFS.
2. Узнайте UUID новой файловой системы.
3. Пропишите её в `/etc/fstab` так, чтобы она монтировалась при загрузке **по UUID**, с
   точкой монтирования `/mnt/labdata`. Используйте опцию `nofail`, чтобы ошибка не
   уводила загрузку в аварийный режим.
4. Смонтируйте без перезагрузки через `mount -a` и проверьте.

> ⚠ `mkfs` стирает содержимое устройства. Выполняйте только на пустом запасном диске,
> имя которого проверили в `lsblk`. Не трогайте диск с корнем (`/`) и `/boot/efi`.

## Проверка
```bash
SPARE=/dev/nvme1n1                 # подставьте свой пустой диск
sudo mkfs.xfs "$SPARE"
sudo blkid "$SPARE"
sudo mkdir -p /mnt/labdata
# добавить в /etc/fstab строку вида:
# UUID=<из blkid>  /mnt/labdata  xfs  defaults,nofail  0 0
sudo mount -a
findmnt /mnt/labdata
```

## Ожидаемый результат
```
/dev/nvme1n1: UUID="..." TYPE="xfs"
```
```
TARGET      SOURCE         FSTYPE OPTIONS
/mnt/labdata /dev/nvme1n1  xfs    rw,relatime,...,nofail
```
`findmnt` показывает, что `/mnt/labdata` смонтирован, хотя в fstab записан UUID, а не
`/dev/nvme1n1`. Так и требует цель экзамена: монтирование переживёт перезагрузку и
перетасовку имён `nvme`. Проверить запись fstab, не перезагружаясь, помогает
`findmnt --verify`. Источник: RHEL 10, «Managing storage devices», раздел 2.1;
`man 5 fstab`, `man 8 mount`.

Уборка после задания: `sudo umount /mnt/labdata`, убрать строку из `/etc/fstab`,
`sudo wipefs -a "$SPARE"` — вернуть диск пустым.
