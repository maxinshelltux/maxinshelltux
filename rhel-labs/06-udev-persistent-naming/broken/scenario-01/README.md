# Сценарий 01: «добавил диск в fstab — система не загрузилась»

Цель экзамена: EX200 (RHEL 10) — **Configure systems to mount file systems at boot by
universally unique ID (UUID) or label** (*Configure local storage*).

## Симптом
В `/etc/fstab` добавили монтирование диска по имени ядра (`/dev/nvme1n1`). После
перезагрузки SSH не отвечает, а с консоли система в emergency:

```text
You are in emergency mode. After logging in, type "journalctl -xb" to view
system logs, "systemctl reboot" to reboot, or "exit" to boot into default mode.
Cannot open access to console, the root account is locked.
```

> ВНИМАНИЕ. `make-broken.sh --apply` добавляет сбойную строку в `/etc/fstab`. После
> перезагрузки монтирование упадёт и система уйдёт в emergency; root на стенде
> заблокирован, поэтому вернуть её можно только с консоли через `rd.break` (лаба 04).
> Запускайте с ментором и при открытой консоли.

```bash
sudo ./broken/scenario-01/make-broken.sh            # покажет строку, которую добавит
sudo ./broken/scenario-01/make-broken.sh --apply    # воспроизвести (после reboot — emergency!)
```

## Диагностика
Запись можно проверить, **не перезагружаясь** — это и есть правильная привычка:

```bash
findmnt --verify
# /mnt/labdata: unreachable source: /dev/nvme1n1
# ... parse error / warnings ...

grep -vE '^[[:space:]]*#' /etc/fstab
# ...
# /dev/nvme1n1  /mnt/labdata  xfs  defaults  0 0        <- имя ядра, без nofail
```
Две ошибки сразу: монтирование по имени ядра (`/dev/nvme1n1` при следующей загрузке может
указывать на другой диск) и отсутствие `nofail` (сбой монтирования уводит загрузку в
emergency). На диске к тому же нет файловой системы.

## Причина
Имена `nvme` на стенде не закреплены за дисками (см. `03-memory`), а `/etc/fstab` без
`nofail` делает каждую запись обязательной для загрузки. Монтирование по имени ядра —
ровно то, против чего направлена цель экзамена: монтировать нужно по UUID или label.

## Решение
Разбор — `solutions/01-fstab-persistent/`. Убрать сбойную строку (или переписать её по
UUID с `nofail`) и проверить до перезагрузки:

```bash
sudo ./solutions/01-fstab-persistent/fix.sh
findmnt --verify && echo "fstab в порядке"
```
Правильная запись выглядит так (UUID берётся из `blkid` после создания ФС):
```text
UUID=<uuid>  /mnt/labdata  xfs  defaults,nofail  0 0
```

## Урок
В `/etc/fstab` монтируйте по `UUID=`/`LABEL=`, а не по `/dev/имя-ядра`. Для некритичных
монтирований добавляйте `nofail`, чтобы ошибка не роняла загрузку в emergency. И всегда
проверяйте новую запись `findmnt --verify` **до** перезагрузки.

После разбора верните стенд: `sudo ./verify/cleanup.sh` (он предупредит о строке в fstab,
но сам её не трогает — уберите фиксом выше).
