# 05 — systemd: target'ы и анализ загрузки: ответы на вопросы

Ответы опираются на выводы из README (стенд `rhel10-lab`, RHEL 10.2,
`systemd-257-23.el10_2`, выводы сняты 2026-10-05 и 2026-10-10) и на официальные
источники: документация RHEL 10 «Using systemd unit files to customize and optimize
your system» (разделы 3.1–3.5 «Booting into a target system state» и 5.1 «Examining
system boot performance»), `man 5 systemd.target`, `man 7 systemd.special`,
`man 7 bootup`, `man 1 systemctl`, `man 1 systemd-analyze`.

## Итоговые вопросы

**1. Чем target отличается от прежнего runlevel и как они связаны?**
Runlevel — это число (0–6) и ровно один режим за раз. Target — это именованный
юнит-«цель», которая через `Requires=`/`Wants=` тянет за собой набор других юнитов, и
их может одновременно действовать несколько (`multi-user.target` активен и внутри
`graphical.target`). Для совместимости systemd держит символические ссылки:
`runlevel3.target → multi-user.target`, `runlevel5.target → graphical.target`,
`runlevel1.target → rescue.target`, `runlevel0/6 → poweroff/reboot`. `who -r` и
`runlevel` показывают число, но настоящая модель — target'ы (`man 7 bootup`).

**2. В чём разница между `systemctl isolate <t>` и `systemctl set-default <t>`?**
`isolate` переключает **работающую** систему в target прямо сейчас и ничего не оставляет
на будущее: после перезагрузки система снова придёт в target по умолчанию. `set-default`
не меняет текущий режим, а переустанавливает симлинк `/etc/systemd/system/default.target`
— это вступит в силу при **следующей** загрузке и будет действовать постоянно. На стенде
это видно так: `isolate graphical.target` поднял graphical, но `get-default` остался
`multi-user.target`; наоборот, `set-default graphical.target` не изменил текущий режим,
но после перезагрузки система сама пришла в graphical.

**3. Почему `systemctl isolate basic.target` не выполняется, а `isolate graphical.target` — да?**
Isolate разрешён только для target'ов, у которых в юните стоит `AllowIsolate=yes`. У
`multi-user`, `graphical`, `rescue`, `emergency` он `yes`, у `basic.target` —
`no`. Поэтому `systemctl isolate basic.target` отвечает `Operation refused, unit may not
be isolated`. Проверить флаг: `systemctl show -p AllowIsolate --value <t>`.

**4. Чем rescue.target отличается от emergency.target и почему оба на стенде не дают оболочку?**
`rescue.target` поднимает базовую систему: монтирует локальные файловые системы и
запускает минимум служб, но не активирует сеть (в опыте `sshd` и `NetworkManager`
неактивны, `ss -tln` пуст). `emergency.target` — ещё раньше: ничего лишнего не
монтирует и не поднимает сеть, только аварийная оболочка на основной консоли. Оба режима
дают оболочку через `sulogin`, который требует пароль root. На стенде root заблокирован,
поэтому `sulogin` отвечает `Cannot open access to console, the root account is locked` и
оболочки не даёт. Этим rescue/emergency отличаются от `rd.break` (лаба 04): тот спрашивает
пароль **initramfs** (пустой), а не установленной системы, — потому и помогает, когда
пароль root неизвестен.

**5. Что сильнее — `systemd.unit=` в командной строке ядра или `set-default`, и как это увидеть?**
`systemd.unit=` на командной строке ядра перекрывает target по умолчанию. Когда он задан,
`systemctl get-default` прямо предупреждает: `Note: found "systemd.unit" on the kernel
command line, which overrides the default unit` — и всё равно печатает значение из
симлинка (`multi-user.target`), хотя загрузка пришла в другой target. Поэтому при
расхождении «get-default одно, а загрузился другой target» первым делом смотрят
`/proc/cmdline` и `grubby --info`. Это и есть ловушка инцидента 2.

**6. Почему в `systemd-analyze blame` наверху `*.device`-юниты и почему их времена не складываются в общее?**
`blame` печатает, сколько каждый юнит инициализировался, по убыванию. У `*.device`-юнитов
(`dev-ttyS0.device`, `…-nvme-….device`) «время» — это ожидание, пока устройство появится,
а не работа службы; такие ожидания идут параллельно и накладываются, поэтому сумма `blame`
больше общего времени и ничего не значит сама по себе. Что действительно определило момент
выхода в target, показывает `critical-chain` — цепочку зависимостей (на стенде её держат
`cloud-init-local.service` и `NetworkManager-wait-online.service`). Красный текст в выводе
— юниты, критически замедляющие загрузку. Общее же время по фазам (ядро/initrd/userspace)
даёт `systemd-analyze` без аргументов.

## Контрольные к инцидентам

**Инцидент 1. После перезагрузки машина ушла в rescue и не пускает по SSH — с чего начать?**
С `systemctl get-default`. Если он показывает `rescue.target` — кто-то сделал
`set-default rescue.target`; это постоянная настройка (симлинк `default.target`). Чинят
`systemctl set-default multi-user.target` и перезагрузкой. Если же `get-default` показывает
`multi-user.target`, а грузится всё равно rescue — причина не здесь, см. инцидент 2.

**Инцидент 2. `get-default` говорит multi-user, но система грузится в rescue — где смотреть?**
В командной строке ядра: `cat /proc/cmdline | tr ' ' '\n' | grep systemd.unit` и
`grubby --info=ALL`. Параметр `systemd.unit=rescue.target` в записи перекрывает
`default.target` и живёт постоянно. Убрать: `grubby --update-kernel=ALL
--remove-args="systemd.unit"` и перезагрузиться.
