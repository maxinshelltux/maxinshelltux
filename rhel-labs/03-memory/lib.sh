#!/usr/bin/env bash
# shellcheck shell=bash

# shellcheck disable=SC2034
LAB_STATE_DIR=/var/lib/rhel-labs/03-memory
LAB_UNIT=lab-memhog.service
LAB_OOM_UNIT=lab-oom.scope
LAB_SWAP_LABEL=labswap
PYTHON=/usr/bin/python3

meminfo_kb() { awk -v key="$1:" '$1 == key {print $2}' /proc/meminfo; }

meminfo_mib() { echo $(( $(meminfo_kb "$1") / 1024 )); }

status_kb() { awk -v key="$2:" '$1 == key {print $2}' "/proc/$1/status" 2>/dev/null; }

top_rss_pid() { ps -eo pid= --sort=-rss | head -n 1 | tr -d ' '; }

unit_pid() { systemctl show -p MainPID --value "$LAB_UNIT"; }

unit_active() { systemctl is-active --quiet "$LAB_UNIT"; }

start_hog() {
  local mib="$1"
  shift
  systemd-run --quiet --unit="${LAB_UNIT%.service}" -p MemoryMax=500M "$@" \
    "$PYTHON" "$MEMHOG" "$mib" --touch --hold 900
}

wait_rss_mib() {
  local pid="$1" want="$2" rss
  for _ in $(seq 1 40); do
    rss="$(status_kb "$pid" VmRSS)"
    if [[ -n "$rss" && $((rss / 1024)) -ge "$want" ]]; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

wait_gone() {
  local pid="$1"
  for _ in $(seq 1 40); do
    [[ -d "/proc/$pid" ]] || return 0
    sleep 0.25
  done
  return 1
}

stop_lab_units() {
  systemctl stop "$LAB_UNIT" 2>/dev/null || true
  systemctl reset-failed "$LAB_UNIT" "$LAB_OOM_UNIT" 2>/dev/null || true
}

lab_swap_dev() {
  lsblk -rnpo NAME,PARTLABEL | awk -v label="$LAB_SWAP_LABEL" '$2 == label {print $1}' | head -n 1
}

lab_swap_uuid() {
  local dev
  dev="$(lab_swap_dev)"
  [[ -n "$dev" ]] || return 0
  blkid -s UUID -o value "$dev" || true
}

lab_swap_active() {
  local dev
  dev="$(lab_swap_dev)"
  [[ -n "$dev" ]] || return 1
  swapon --noheadings --show=NAME | grep -qx "$dev"
}

fstab_swap_line() {
  local uuid
  uuid="$(lab_swap_uuid)"
  [[ -n "$uuid" ]] || return 0
  grep -nE "^UUID=${uuid}[[:space:]]+none[[:space:]]+swap[[:space:]]" /etc/fstab || true
}

empty_disks() {
  local disk
  while IFS= read -r disk; do
    if [[ "$(lsblk -no NAME "$disk" | wc -l)" -eq 1 && -z "$(lsblk -dno FSTYPE "$disk")" ]]; then
      echo "$disk"
    fi
  done < <(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" {print $1}')
}
