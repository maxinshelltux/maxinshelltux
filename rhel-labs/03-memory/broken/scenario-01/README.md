# Сценарий 01: «процесс убили, а он вернулся»

Цели EX200 (RHEL 10): **Identify CPU/memory intensive processes and kill processes**
и **Start and stop services and configure services to start automatically at boot**.

## Симптом
Память уходит. Виновник найден и убит, но через пару секунд он снова на месте.
```bash
sudo ./broken/scenario-01/make-broken.sh
# Заявка: «Память на сервере уходит. Нашёл процесс, который её ест, убил его —
# через пару секунд он снова на месте и снова занимает столько же».
#
# Что видит автор заявки:
# # free -m
#                total        used        free      shared  buff/cache   available
# Mem:            1647         667         646           7         480         979
# Swap:              0           0           0
# # ps -eo pid,user,rss,pmem,args --sort=-rss | head -n 3
#     PID USER       RSS %MEM COMMAND
#   10347 root     318856 18.9 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
#       1 root     36156  2.1 /usr/lib/systemd/systemd --switched-root --system --deserialize=50

kill 10347; sleep 4; pgrep -af memhog.py
# 10364 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
```
PID был 10347, стал 10364: это новый процесс.

## Подсказки
1. Кто родитель нового процесса? Посмотрите колонку PPID.
2. Процесс не появляется сам. Кто мог запустить его заново?
3. Как по PID узнать, какой службе принадлежит процесс?

## Диагностика
```bash
ps -o pid,ppid,user,unit,args -p 10364
#     PID    PPID USER     UNIT                            COMMAND
#   10364       1 root     lab-memhog.service              /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900

cat /proc/10364/cgroup
# 0::/system.slice/lab-memhog.service

systemctl status 10364 --no-pager | head -n 9
# ● lab-memhog.service - [systemd-run] /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
#      Loaded: loaded (/run/systemd/transient/lab-memhog.service; transient)
#   Transient: yes
#      Active: active (running) since Mon 2026-10-05 14:03:33 UTC; 1s ago
#  Invocation: 4850ebc7aef64255bc643716033a0c7c
#    Main PID: 10364 (python3)
#       Tasks: 1 (limit: 9735)
#      Memory: 305.7M (max: 500M, available: 194.2M, peak: 305.8M)
#         CPU: 91ms

systemctl show -p Restart -p RestartUSec -p MemoryMax lab-memhog.service
# Restart=always
# RestartUSec=2s
# MemoryMax=524288000
```
Родитель процесса — PID 1, то есть `systemd`. Процесс принадлежит службе
`lab-memhog.service`, а у неё `Restart=always`: как только процесс завершается,
`systemd` через две секунды запускает его снова. `kill` здесь бесполезен, сколько
его ни повторяй.

`systemctl status <PID>` принимает PID и сам находит службу — запомните этот приём.

## Решение
Остановить службу, а не процесс (см. `solutions/01-respawning-hog/fix.sh`):
```bash
sudo ./solutions/01-respawning-hog/fix.sh
# самый прожорливый процесс:
#     PID    PPID USER       RSS %MEM COMMAND
#   10364       1 root     318784 18.8 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
# его юнит: lab-memhog.service, Restart=always
# [OK] lab-memhog.service остановлен, процесс не вернулся
#                total        used        free      shared  buff/cache   available
# Mem:            1647         420         893           7         480        1226
# Swap:              0           0           0
```
Вручную то же самое: `systemctl stop lab-memhog.service`.

## Урок
Прежде чем убивать процесс, посмотрите, кто его запустил: `ps -o pid,ppid,unit -p
<PID>` или `systemctl status <PID>`. Процесс службы останавливают через `systemctl
stop`.

После разбора стенд уже в порядке; для уверенности — `sudo ./verify/cleanup.sh`.
