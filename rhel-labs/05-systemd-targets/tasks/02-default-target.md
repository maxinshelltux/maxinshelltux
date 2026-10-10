# 02 — Задать target, в который система загружается по умолчанию

## Цель экзамена
EX200 (RHEL 10), раздел *Operate running systems*:
**Boot systems into different targets manually**. Общее требование экзамена с той же
страницы: «configurations must persist after reboot without intervention» — target по
умолчанию как раз должен пережить перезагрузку.

## Задача
1. Покажите текущий target по умолчанию и симлинк, которым он задан.
2. Сделайте так, чтобы система по умолчанию загружалась в `graphical.target`.
3. Перезагрузитесь и докажите, что система сама пришла в `graphical.target`.
4. Верните значение по умолчанию на `multi-user.target`.

> ⚠ `graphical.target` на этом стенде безопасен (тянет `multi-user.target`, поэтому SSH
> остаётся). Никогда не ставьте по умолчанию `rescue.target` или `emergency.target`:
> после перезагрузки в них нет сети и SSH, вернуть можно только с консоли (инцидент 1).
> Перезагрузки согласуйте с ментором.

## Проверка
```bash
systemctl get-default
ls -l /etc/systemd/system/default.target
systemctl set-default graphical.target
systemctl get-default
# systemctl reboot   # с ведома ментора
# после перезагрузки:
systemctl get-default
systemctl is-active graphical.target
systemctl set-default multi-user.target
```

## Ожидаемый результат
```
multi-user.target
lrwxrwxrwx. ... /etc/systemd/system/default.target -> /usr/lib/systemd/system/multi-user.target
Removed '/etc/systemd/system/default.target'.
Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/graphical.target'.
graphical.target
# после перезагрузки:
graphical.target
active
Removed '/etc/systemd/system/default.target'.
Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/multi-user.target'.
```
`set-default` — это всего лишь симлинк `/etc/systemd/system/default.target`. Поэтому
настройка переживает перезагрузку. Имя target проверяется: `systemctl set-default
multiuser.target` даёт `Unit multiuser.target does not exist`, а не-target —
`Invalid argument`. Источник: RHEL 10, «Using systemd unit files…», раздел 3.2.
