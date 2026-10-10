# 03 — Дать устройству свой постоянный симлинк правилом udev

## Цель экзамена
Отдельной цели про правила udev в EX200 нет — это смежный материал из раздела
документации RHEL 10 «Managing storage devices» (2.2 «udev device naming rules»). Он
объясняет, откуда вообще берутся имена в `/dev/disk/*` из заданий 01–02, и как сделать
своё устойчивое имя.

## Задача
1. Для запасного диска узнайте его `ID_SERIAL_SHORT` (задание 01).
2. Напишите в `/etc/udev/rules.d/` правило, которое по этому серийному номеру создаёт
   симлинк `/dev/lab-spare` на диск — независимо от того, какое у него имя ядра.
3. Перечитайте правила и примените их к устройству; убедитесь, что `/dev/lab-spare`
   появился и указывает на нужный диск.
4. Уберите правило и верните состояние.

## Проверка
```bash
SPARE=/dev/nvme1n1
SHORT=$(sudo udevadm info --name "$SPARE" --query property --property ID_SERIAL_SHORT --value)

printf '%s\n' "SUBSYSTEM==\"block\", ENV{ID_SERIAL_SHORT}==\"$SHORT\", SYMLINK+=\"lab-spare\"" \
  | sudo tee /etc/udev/rules.d/99-lab-spare.rules

sudo udevadm control --reload
sudo udevadm trigger --name-match="$(basename "$SPARE")" --action=change
sudo udevadm settle
ls -l /dev/lab-spare
```

## Ожидаемый результат
```
SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="vol0ed094b9462cbadc2", SYMLINK+="lab-spare"
lrwxrwxrwx. 1 root root 7 ... /dev/lab-spare -> nvme1n1
```
Правило в `/etc/udev/rules.d/` (не в `/usr/lib/udev/rules.d/`, которую перезаписывают
обновления) сопоставляется по свойству устройства `ID_SERIAL_SHORT` и добавляет симлинк
через `SYMLINK+=`. Серийный номер к диску привязан, поэтому `/dev/lab-spare` будет
указывать на него при любом имени ядра. Источник: RHEL 10, «Managing storage devices»,
раздел 2.2; `man 7 udev`, `man 8 udevadm`.

Уборка: `sudo rm /etc/udev/rules.d/99-lab-spare.rules`, затем
`sudo udevadm control --reload && sudo udevadm trigger --name-match=nvme1n1 --action=change`.
