# Сценарий 02: «написал правило udev, а симлинк не появляется»

Цель экзамена: отдельной цели про udev в EX200 нет; сценарий закрепляет материал части 3
(документация RHEL 10 «Managing storage devices», 2.2) — где искать ошибку в правиле.

## Симптом
Правило udev для симлинка на диск вроде бы написано, `reload` и `trigger` сделаны, а
`/dev/lab-spare` не появляется. SSH при этом работает — правило просто не срабатывает.

```bash
sudo ./broken/scenario-02/make-broken.sh
# ...
# симлинк /dev/lab-spare:
# ls: cannot access '/dev/lab-spare': No such file or directory
```

## Диагностика
Проверяют правило против конкретного устройства командой `udevadm test`:

```bash
sudo udevadm test /sys/class/block/nvme1n1 2>&1 | grep -iE 'lab-spare|99-lab'
# (пусто — ни одно учебное правило не дало симлинк)

# что реально есть у устройства:
sudo udevadm info --name /dev/nvme1n1 --query property | grep ID_SERIAL
# ID_SERIAL=Amazon_Elastic_Block_Store_vol0ed094b9462cbadc2_1
# ID_SERIAL_SHORT=vol0ed094b9462cbadc2

cat /etc/udev/rules.d/99-lab-broken.rules
# SUBSYSTEM=="block", ENV{ID_SERIAL}=="vol0ed094b9462cbadc2", SYMLINK+="lab-spare"
```
Видно расхождение: правило сравнивает `ENV{ID_SERIAL}` (длинная форма,
`Amazon_..._vol..._1`) со значением короткой формы (`vol...`). Условие никогда не
истинно, поэтому `SYMLINK+=` не выполняется.

## Причина
Перепутан ключ: у устройства есть и `ID_SERIAL`, и `ID_SERIAL_SHORT`, и это разные
строки. Правило должно сравнивать то свойство, значение которого вы подставили.
Частые ошибки того же рода: `=` вместо `==` в условии и забытый `udevadm control --reload`
после правки файла.

## Решение
Разбор — `solutions/02-fix-udev-rule/`. Убрать сбойное правило и написать верное — с
`ENV{ID_SERIAL_SHORT}`:

```bash
sudo ./solutions/02-fix-udev-rule/fix.sh
# затем правильное правило (задание 03):
SHORT=$(sudo udevadm info --name /dev/nvme1n1 --query property --property ID_SERIAL_SHORT --value)
printf '%s\n' "SUBSYSTEM==\"block\", ENV{ID_SERIAL_SHORT}==\"$SHORT\", SYMLINK+=\"lab-spare\"" \
  | sudo tee /etc/udev/rules.d/99-lab-spare.rules
sudo udevadm control --reload
sudo udevadm trigger --name-match=nvme1n1 --action=change
ls -l /dev/lab-spare
```

## Урок
Правило udev отлаживают `udevadm test <sysfs-путь>`: он показывает, какие правила
применились и какой симлинк получился. Сверяйте имя ключа (`ID_SERIAL` ≠
`ID_SERIAL_SHORT`), оператор (`==` для сравнения) и не забывайте `udevadm control
--reload` после правки. Источник: `man 8 udevadm`, `man 7 udev`.

После разбора стенд в порядке; для уверенности — `sudo ./verify/cleanup.sh`.
