# Сценарий 01: «после перезагрузки машина ушла в rescue и не пускает по SSH»

Цель экзамена: EX200 (RHEL 10) — **Boot systems into different targets manually**
(*Operate running systems*).

## Симптом
Машину перезагрузили, и она перестала отвечать по SSH:

```bash
ssh ec2-user@<ip>
# ssh: connect to host <ip> port 22: Connection refused
```

С консоли видно, что система остановилась в rescue. На стенде, где root заблокирован,
`sulogin` даже не даёт оболочку:

```text
You are in rescue mode. After logging in, type "journalctl -xb" to view
system logs, "systemctl reboot" to reboot, or "exit" to continue bootup.
Cannot open access to console, the root account is locked.
Press Enter to continue.
```

> ВНИМАНИЕ. `make-broken.sh --apply` переводит target по умолчанию в `rescue.target`.
> После перезагрузки не будет ни сети, ни SSH, и вернуть систему можно только с консоли.
> Запускайте с ментором и при открытой консоли.

```bash
sudo ./broken/scenario-01/make-broken.sh            # покажет, что сделает
sudo ./broken/scenario-01/make-broken.sh --apply    # воспроизвести (после reboot рвёт SSH!)
```

## Диагностика
С консоли (root в rescue тут не пускает, поэтому диагностируют уже после возврата или
при незаблокированном root):

```bash
systemctl get-default
# rescue.target

ls -l /etc/systemd/system/default.target
# ... default.target -> /usr/lib/systemd/system/rescue.target
```
`get-default` прямо показывает причину: target по умолчанию — `rescue.target`. Это
постоянная настройка (симлинк `/etc/systemd/system/default.target`), поэтому она
срабатывает при каждой загрузке.

## Причина
Кто-то выполнил `systemctl set-default rescue.target` — возможно, хотел разово
загрузиться в rescue, но сделал это значением по умолчанию вместо разовой правки в меню
GRUB (`systemd.unit=rescue.target`, часть 3) или команды `systemctl rescue` на лету
(часть 2).

## Решение
Разбор — `solutions/01-default-target/`. Вернуть значение по умолчанию и перезагрузиться:

```bash
sudo systemctl set-default multi-user.target
# Removed '/etc/systemd/system/default.target'.
# Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/multi-user.target'.

systemctl get-default
# multi-user.target

sudo systemctl reboot
```

## Урок
`set-default` меняет target **навсегда**. Для разового входа в rescue есть `systemctl
rescue` (на работающей системе) и `systemd.unit=rescue.target` в меню GRUB (одна
загрузка). `rescue.target`/`emergency.target` по умолчанию на машине без консоли —
это потеря доступа: сверяйте `systemctl get-default` после любых опытов с target.

После разбора стенд уже в порядке; для уверенности — `sudo ./verify/cleanup.sh`.
