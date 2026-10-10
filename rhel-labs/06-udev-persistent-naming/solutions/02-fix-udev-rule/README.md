# Решение сценария 02: правило udev не создаёт симлинк

Инцидент: `broken/scenario-02/`. Правило в `/etc/udev/rules.d/99-lab-broken.rules`
сопоставляет `ENV{ID_SERIAL}` со значением короткой формы серийника, из-за чего условие
никогда не совпадает и `/dev/lab-spare` не появляется.

`fix.sh` убирает сбойное учебное правило, перечитывает и переприменяет правила и
подсказывает верный ключ:

```bash
sudo ./solutions/02-fix-udev-rule/fix.sh
# удалено сбойное правило: /etc/udev/rules.d/99-lab-broken.rules
# [OK] сбойные учебные правила убраны, правила перечитаны
# верный ключ для запасного диска /dev/nvme1n1:
#     ENV{ID_SERIAL_SHORT}=="vol0ed094b9462cbadc2"
# правильное правило см. tasks/03-udev-symlink.md
```

Дальше пишут верное правило (см. `tasks/03-udev-symlink.md`) — сравнение по тому ключу,
значение которого подставляете:

```bash
SHORT=$(sudo udevadm info --name /dev/nvme1n1 --query property --property ID_SERIAL_SHORT --value)
printf '%s\n' "SUBSYSTEM==\"block\", ENV{ID_SERIAL_SHORT}==\"$SHORT\", SYMLINK+=\"lab-spare\"" \
  | sudo tee /etc/udev/rules.d/99-lab-spare.rules
sudo udevadm control --reload
sudo udevadm trigger --name-match=nvme1n1 --action=change
sudo udevadm settle
ls -l /dev/lab-spare
# lrwxrwxrwx. ... /dev/lab-spare -> nvme1n1
```

Отладка правил — `udevadm test /sys/class/block/<устройство>`: он показывает, какие
правила применились и какой симлинк получился. Сверяйте ключ (`ID_SERIAL` ≠
`ID_SERIAL_SHORT`), оператор (`==` для сравнения) и `udevadm control --reload` после
правки. Источник: `man 8 udevadm`, `man 7 udev`.

Уборка учебного правила — `sudo ./verify/cleanup.sh`.
