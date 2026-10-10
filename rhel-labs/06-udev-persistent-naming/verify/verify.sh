#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=06-udev-persistent-naming/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_rhel10
need_bin udevadm
need_bin blkid
need_bin lsblk
need_bin findmnt

MISSING="$(missing_persist_dirs)"
[[ -z "$MISSING" ]] || fail "нет каталогов постоянных имён: $MISSING"
ok "каталоги постоянных имён на месте: $PERSIST_DIRS"

ROOT_DEV="$(root_source)"
LINKS="$(devlinks "$ROOT_DEV")"
[[ -n "$LINKS" ]] || fail "udevadm не отдал DEVLINKS для корня ($ROOT_DEV): udev не работает"
[[ "$LINKS" == *"/dev/disk/by-uuid/"* ]] \
  || fail "у корневого устройства $ROOT_DEV нет ссылки by-uuid — странно для udev"
ok "udevadm видит корень $ROOT_DEV и его by-uuid ссылку"

KERNEL_ENTRIES="$(fstab_kernel_name_entries)"
[[ -z "$KERNEL_ENTRIES" ]] \
  || fail "в /etc/fstab монтирование по имени ядра (неустойчиво к перезагрузке): $KERNEL_ENTRIES"
ok "в /etc/fstab нет монтирования по имени ядра — только UUID/LABEL/by-*"

UNRESOLVED="$(fstab_unresolved)"
[[ -z "$UNRESOLVED" ]] \
  || fail "в /etc/fstab есть UUID/LABEL, которых нет в системе: $UNRESOLVED (монтирование упадёт при загрузке)"
ok "все UUID/LABEL из /etc/fstab разрешаются в реальные устройства"

RULES="$(lab_rules)"
[[ -z "$RULES" ]] \
  || fail "остались учебные правила udev: $RULES (sudo ./verify/cleanup.sh)"
ok "учебных правил udev ($RULE_DIR/${LAB_RULE_PREFIX}*.rules) нет"

SYMS="$(lab_symlinks)"
if [[ -n "$SYMS" ]]; then
  warn "есть учебные симлинки /dev/lab-*: $SYMS — убрать: sudo ./verify/cleanup.sh"
else
  ok "учебных симлинков /dev/lab-* нет"
fi

ok "module 06-udev-persistent-naming verified"
