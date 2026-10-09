# Сценарий 01: «сбросил пароль root, а теперь никто не может войти»

Цель экзамена: EX200 (RHEL 10) — **Restore default file contexts** и **List and
identify SELinux file and process context** (*Manage security*).

## Симптом
Коллега сбросил пароль root через `rd.break`, но забыл `touch /.autorelabel`. После
перезагрузки:

- вход под root в консоли с новым паролем не проходит;
- `sudo` и `su` обычного пользователя падают, хотя пароль верный;
- SSH по ключу перестаёт пускать — соединение закрывается сразу.

```bash
sudo ./broken/scenario-01/make-broken.sh            # покажет, что сделает
sudo ./broken/scenario-01/make-broken.sh --apply    # воспроизвести (обрывает SSH и sudo!)
```

> ВНИМАНИЕ. `--apply` оставляет `/etc/shadow` с неверной меткой. После этого вход по
> SSH и `sudo` работать перестают, и вернуть систему можно только с консоли стенда.
> Запускайте с ментором и при открытой консоли.

Как это выглядит на попытке выполнить что-либо через `sudo` после поломки:
```
sudo: PAM account management error: Authentication service cannot retrieve authentication info
sudo: a password is required
```

## Диагностика
Если root-доступ ещё есть (например, успели заметить до перезагрузки или загрузились в
permissive — см. ниже), метку видно сразу:
```bash
ls -Z /etc/shadow
# system_u:object_r:user_tmp_t:s0 /etc/shadow      <- должно быть shadow_t

restorecon -n -v /etc/shadow
# Would relabel /etc/shadow from system_u:object_r:user_tmp_t:s0 to system_u:object_r:shadow_t:s0
```
`restorecon -n` только показывает, что политика хочет метку `shadow_t`, а на файле
другая. Под Enforcing модуль `pam_unix` не может прочитать такой `/etc/shadow` — отсюда
отказы входа, `sudo`, `su` и SSH.

## Причина
В оболочке `rd.break` политика SELinux не загружена. Файл, записанный `passwd`,
получает метку по умолчанию (здесь `user_tmp_t`), а не `shadow_t`. `touch /.autorelabel`
нужен именно для того, чтобы при следующей загрузке метки расставились заново. Без него
метка остаётся неверной.

## Решение
Разбор — `solutions/01-shadow-relabel/`. Коротко:

- **Если root-доступ ещё есть** (успели до перезагрузки или загрузились с `enforcing=0`):
  `restorecon -v /etc/shadow`.
- **Если вы уже заперты** (SSH и `sudo` не пускают): с консоли через `rd.break`. Важно:
  `restorecon` прямо из оболочки `rd.break` метку **не исправит** — там SELinux не
  загружен, и команда молча ничего не меняет. Надёжный путь из `rd.break` — заказать
  полную перемаркировку:

  ```text
  меню GRUB -> e -> строка linux -> Ctrl+e -> " rd.break" -> Ctrl+x
  Enter
  mount -o remount,rw /sysroot
  chroot /sysroot
  touch /.autorelabel
  exit
  exit
  ```

  Система перемаркирует файлы, вернёт `/etc/shadow` метку `shadow_t`, удалит
  `/.autorelabel` и перезагрузится. После этого вход и `sudo` снова работают.

## Урок
`touch /.autorelabel` в процедуре сброса пароля — обязательный шаг, а не
перестраховка. Пропустив его, вы запираете систему. И помните: из оболочки `rd.break`
чинит метку не `restorecon`, а перемаркировка через `/.autorelabel`.

После разбора верните стенд: `sudo ./verify/cleanup.sh` и, если нужно,
`sudo restorecon -v /etc/shadow`.
