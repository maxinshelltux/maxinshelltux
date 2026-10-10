# 03 — Разобрать, из чего складывается время загрузки

## Цель экзамена
Отдельной цели про `systemd-analyze` в EX200 нет — это смежный инструмент из раздела
документации RHEL 10 «Optimizing systemd to shorten the boot time» (5.1). Он помогает в
цели *Operate running systems* понимать, что происходит при загрузке, и читать её
результат вместе с `systemctl` и журналом.

## Задача
1. Покажите общее время загрузки по фазам (ядро, initrd, userspace).
2. Найдите юнит, который дольше всех инициализировался.
3. Постройте критическую цепочку — последовательность, которая определила момент выхода
   в `multi-user.target`.
4. Объясните, почему в `blame` наверху часто оказываются `*.device`-юниты.

## Проверка
```bash
systemd-analyze
systemd-analyze blame | head
systemd-analyze critical-chain
```

## Ожидаемый результат
```
Startup finished in 6.894s (kernel) + 7.647s (initrd) + 18.781s (userspace) = 33.323s
multi-user.target reached after 17.128s in userspace.
```
(числа будут свои). В `blame` вверху — `*.device`-юниты (`dev-ttyS0.device`,
`…-nvme-….device`): их «время» — это ожидание появления устройства, а не работа службы,
поэтому их длительности не складываются и не равны общему времени. `critical-chain`
показывает именно цепочку зависимостей, задержавшую выход в target (на стенде её держат
`cloud-init-local.service` и `NetworkManager-wait-online.service`). Красный текст в
выводе — это юниты, критически замедляющие загрузку. Источник: RHEL 10, «Using systemd
unit files…», раздел 5.1; `man 1 systemd-analyze`.
