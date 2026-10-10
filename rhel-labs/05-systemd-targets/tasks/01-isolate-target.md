# 01 — Переключить работающую систему в другой target и обратно

## Цель экзамена
EX200 (RHEL 10), раздел *Operate running systems*:
**Boot systems into different targets manually**.

## Задача
Не перезагружаясь:

1. Покажите, какой target активен сейчас и какой стоит по умолчанию.
2. Переключите работающую систему в `graphical.target` командой `systemctl isolate`.
3. Убедитесь, что `multi-user.target` при этом остался активным, а `sshd` и сеть никуда
   не делись.
4. Верните систему в исходный target через `systemctl isolate default.target`.
5. Покажите на примере `basic.target`, что не всякий target можно сделать isolate.

## Проверка
```bash
systemctl get-default
systemctl is-active multi-user.target graphical.target
systemctl isolate graphical.target
systemctl is-active multi-user.target graphical.target
systemctl isolate default.target
systemctl is-active graphical.target
systemctl show -p AllowIsolate --value basic.target
systemctl isolate basic.target
```

## Ожидаемый результат
```
multi-user.target
active
inactive
# (после isolate graphical.target)
active
active
# (после isolate default.target)
inactive
# basic.target:
no
Failed to start basic.target: Operation refused, unit may not be isolated.
```
`isolate` запускает выбранный target и всё, что он тянет, и останавливает то, что в
новый target не входит. `graphical.target` требует (`Requires=`) `multi-user.target`,
поэтому `sshd` остаётся. `basic.target` имеет `AllowIsolate=no` — в него переключиться
нельзя. Источник: RHEL 10, «Using systemd unit files…», раздел 3.3; `man 5 systemd.target`.
