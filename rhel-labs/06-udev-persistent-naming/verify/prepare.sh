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
[[ -z "$MISSING" ]] \
  || refuse "в системе нет каталогов постоянных имён ($MISSING): udev работает неправильно, лаба бессмысленна"

RULES="$(lab_rules)"
[[ -z "$RULES" ]] \
  || refuse "остались учебные правила udev ($RULES): сначала уберите их — sudo ./verify/cleanup.sh"

install -d -m 700 "$LAB_STATE_DIR"
if [[ ! -f "$LAB_STATE_DIR/baseline.txt" ]]; then
  {
    echo "# снято $(date -u '+%F %T UTC')"
    echo "## lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,SERIAL"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,SERIAL
    echo "## blkid"
    blkid
    echo "## /etc/fstab"
    grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$FSTAB"
    echo "## ls /dev/disk/by-id"
    ls /dev/disk/by-id
  } > "$LAB_STATE_DIR/baseline.txt"
fi

SPARE="$(spare_disk)"
ok "стенд готов: каталоги постоянных имён на месте, запасной диск ${SPARE:-нет}, снимок $LAB_STATE_DIR/baseline.txt"
