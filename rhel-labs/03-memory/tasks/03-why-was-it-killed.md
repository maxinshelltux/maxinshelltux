# 03 — Выяснить по журналу, почему процесс был убит

## Цель экзамена
EX200 (RHEL 10), раздел *Operate running systems*:
**Locate and interpret system log files and journals**.

## Задача
Выполните команду (из каталога модуля, под root). Она завершится неудачей:

```bash
systemd-run --scope --unit=lab-oom -p MemoryMax=200M -p MemorySwapMax=0 ./memhog.py 400 --touch
```

1. Назовите код возврата команды и объясните, что он означает.
2. Найдите в журнале запись о том, кто и почему завершил процесс. Ответьте по ней:
   это нехватка памяти всей системы или предел для группы процессов? Сколько памяти
   процесс успел занять?
3. После опыта система оказалась не в состоянии `running`. Найдите причину и верните
   состояние `running`.

## Проверка
```bash
# шаг 1
echo $?

# шаг 2
journalctl -k --since "-1min" --no-pager -o cat | grep -E 'oom-kill:|Memory cgroup out of memory'

# шаг 3
systemctl is-system-running
systemctl --failed --no-legend --no-pager
systemctl is-system-running        # после исправления
```

## Ожидаемый результат
Шаг 1:
```
137
```
Шаг 2:
```
oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/lab-oom.scope,task_memcg=/system.slice/lab-oom.scope,task=python3,pid=8002,uid=0
Memory cgroup out of memory: Killed process 8002 (python3) total-vm:424804kB, anon-rss:204288kB, file-rss:5956kB, shmem-rss:0kB, UID:0 pgtables:460kB oom_score_adj:0
```
Шаг 3:
```
degraded
● lab-oom.scope loaded failed failed [systemd-run] /home/ec2-user/rhel-labs/03-memory/memhog.py 400 --touch
running
```
(PID у вас свой).

Ответы: 137 = 128 + 9, процесс убит сигналом SIGKILL. `constraint=CONSTRAINT_MEMCG`
и `oom_memcg=/system.slice/lab-oom.scope` говорят, что сработал предел группы
`lab-oom.scope`, а не нехватка памяти в системе. `anon-rss:204288kB` — около
200 МиБ, заданный `MemoryMax`; обещано процессу было 424804 кБ (`total-vm`).

Решение для шага 3:
```bash
systemctl reset-failed lab-oom.scope
```
Разбор — README, часть 5.
