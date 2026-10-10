#!/usr/bin/env bash
# shellcheck shell=bash

# shellcheck disable=SC2034
LAB_STATE_DIR=/var/lib/rhel-labs/06-udev-persistent-naming
RULE_DIR=/etc/udev/rules.d
LAB_RULE_PREFIX=99-lab-
FSTAB=/etc/fstab
PERSIST_DIRS="/dev/disk/by-uuid /dev/disk/by-id /dev/disk/by-path"

root_source() {
  findmnt -no SOURCE /
}

devlinks() {
  udevadm info --name "$1" --query property --property DEVLINKS --value 2>/dev/null
}

lab_rules() {
  find "$RULE_DIR" -maxdepth 1 -name "${LAB_RULE_PREFIX}*.rules" 2>/dev/null | sort
}

lab_symlinks() {
  find /dev -maxdepth 1 -name 'lab-*' 2>/dev/null | sort
}

reload_udev() {
  udevadm control --reload
}

missing_persist_dirs() {
  local d found=""
  for d in $PERSIST_DIRS; do
    [[ -d "$d" ]] || found="$found $d"
  done
  echo "${found# }"
}

spare_disk() {
  local name
  while read -r name; do
    [[ "$(lsblk -rno NAME "/dev/$name" | wc -l)" -eq 1 ]] || continue
    [[ -z "$(lsblk -drno FSTYPE "/dev/$name")" ]] || continue
    echo "/dev/$name"
    return 0
  done < <(lsblk -drno NAME,TYPE | awk '$2 == "disk" { print $1 }')
}

serial_short() {
  udevadm info --name "$1" --query property --property ID_SERIAL_SHORT --value 2>/dev/null
}

fstab_sources() {
  awk '!/^[[:space:]]*#/ && NF >= 2 { print $1 }' "$FSTAB"
}

fstab_kernel_name_entries() {
  local src found=""
  while IFS= read -r src; do
    case "$src" in
      /dev/disk/*) : ;;
      /dev/*) found="$found $src" ;;
    esac
  done < <(fstab_sources)
  echo "${found# }"
}

fstab_unresolved() {
  local src id found=""
  while IFS= read -r src; do
    case "$src" in
      UUID=*) id="${src#UUID=}"; blkid -U "$id" >/dev/null 2>&1 || found="$found $src" ;;
      LABEL=*) id="${src#LABEL=}"; blkid -L "$id" >/dev/null 2>&1 || found="$found $src" ;;
    esac
  done < <(fstab_sources)
  echo "${found# }"
}
