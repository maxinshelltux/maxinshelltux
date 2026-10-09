# Решение сценария 01: неверная метка /etc/shadow

Инцидент: `broken/scenario-01/`. После сброса пароля без `touch /.autorelabel` у
`/etc/shadow` метка `user_tmp_t`, и под Enforcing вход не работает.

Путь зависит от того, остался ли у вас root-доступ.

## Есть root-доступ (успели до перезагрузки или загрузились с enforcing=0)

`fix.sh` это и делает:

```bash
sudo ./solutions/01-shadow-relabel/fix.sh
# до: system_u:object_r:user_tmp_t:s0 /etc/shadow
# Would relabel /etc/shadow from system_u:object_r:user_tmp_t:s0 to system_u:object_r:shadow_t:s0
# Relabeled /etc/shadow from system_u:object_r:user_tmp_t:s0 to system_u:object_r:shadow_t:s0
# после: system_u:object_r:shadow_t:s0 /etc/shadow
# [OK] метка /etc/shadow соответствует политике
```

Вручную то же самое: `restorecon -v /etc/shadow`.

Если система сейчас в permissive (грузили с `enforcing=0`), после починки верните
Enforcing: `setenforce 1` и проверьте `getenforce`.

## Доступа нет (SSH и sudo не пускают)

Чините с консоли через `rd.break`. Внутри аварийной оболочки `restorecon` метку **не
исправит** — там SELinux не загружен. Закажите полную перемаркировку:

```text
меню GRUB -> e -> строка linux -> Ctrl+e -> " rd.break" -> Ctrl+x
Enter
mount -o remount,rw /sysroot
chroot /sysroot
touch /.autorelabel
exit
exit
```

Система перемаркирует файлы, вернёт `shadow_t`, удалит `/.autorelabel` и перезагрузится.
Проверка после входа — как в части 4.4.
