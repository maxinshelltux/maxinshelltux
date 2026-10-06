# 01 — Найти процесс, который съел память, и завершить его

## Цель экзамена
EX200 (RHEL 10), раздел *Operate running systems*:
**Identify CPU/memory intensive processes and kill processes**.

## Задача
На сервере запущен процесс, который занимает заметную часть памяти. Запустите его
командой (из каталога модуля, под root):

```bash
systemd-run --unit=lab-memhog -p MemoryMax=500M /usr/bin/python3 "$PWD/memhog.py" 300 --touch --hold 900
```

1. Найдите процесс, который занимает больше всего памяти. Назовите его PID, размер
   RSS и долю памяти в процентах.
2. Завершите его штатно, сигналом SIGTERM.
3. Докажите, что процесса больше нет и память вернулась системе.

## Проверка
```bash
# шаг 1
free -m
ps -eo pid,user,rss,vsz,pmem,args --sort=-rss | head -n 4

# шаг 3
ps -p <PID>
systemctl is-active lab-memhog.service
free -m
```

## Ожидаемый результат
Шаг 1:
```
               total        used        free      shared  buff/cache   available
Mem:            1647         665         807           7         318         981
Swap:              0           0           0

    PID USER       RSS    VSZ %MEM COMMAND
   6006 root     318652 322420 18.8 /usr/bin/python3 /home/ec2-user/rhel-labs/03-memory/memhog.py 300 --touch --hold 900
      1 root     36156  44404  2.1 /usr/lib/systemd/systemd --switched-root --system --deserialize=50
    793 root     27616 256632  1.6 /usr/bin/python3 -Es /usr/sbin/tuned -l -P
```
Шаг 3:
```
    PID TTY          TIME CMD

inactive

               total        used        free      shared  buff/cache   available
Mem:            1647         385        1087           7         318        1262
Swap:              0           0           0
```
(PID и точные числа у вас свои). Виновник стоит первым в списке, отсортированном по
RSS; после `kill` строка с его PID исчезает, а `available` возвращается к прежнему
значению — на стенде с 981 до 1262 МиБ.

Решение:
```bash
ps -eo pid,user,rss,vsz,pmem,args --sort=-rss | head -n 4
kill <PID>
```
То же через `top`: `top -b -n 1 -o %MEM | head -n 12`, в интерактивном режиме —
клавиша `M`. Разбор — README, часть 4.
