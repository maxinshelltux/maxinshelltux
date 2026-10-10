#!/usr/bin/env bash
# shellcheck shell=bash

# shellcheck disable=SC2034
LAB_STATE_DIR=/var/lib/rhel-labs/05-systemd-targets
BASELINE_TARGET=multi-user.target
LAB_BOOT_KEYS="systemd.unit"
ISOLATABLE_TARGETS="multi-user.target graphical.target rescue.target emergency.target"
CORE_TARGETS="multi-user.target graphical.target rescue.target emergency.target poweroff.target reboot.target"

words_have() {
  local key="$1" word
  while IFS= read -r word; do
    if [[ "$word" == "$key" || "$word" == "$key="* ]]; then
      return 0
    fi
  done < <(tr ' ' '\n')
  return 1
}

kernels() {
  find /boot -maxdepth 1 -name 'vmlinuz-*' ! -name '*rescue*' | sort -V
}

kernel_version() {
  basename "$1" | sed 's/^vmlinuz-//'
}

entry_args() {
  grubby --info="$1" | sed -n 's/^args="\(.*\)"$/\1/p' | head -n 1
}

running_has_arg() {
  words_have "$1" < /proc/cmdline
}

places_with_arg() {
  local key="$1" kernel found=""
  while IFS= read -r kernel; do
    if entry_args "$kernel" | words_have "$key"; then
      found="$found $(kernel_version "$kernel")"
    fi
  done < <(kernels)
  if [[ -f /etc/kernel/cmdline ]] && words_have "$key" < /etc/kernel/cmdline; then
    found="$found /etc/kernel/cmdline"
  fi
  echo "${found# }"
}

lab_unit_in_config() {
  local key found=""
  for key in $LAB_BOOT_KEYS; do
    if [[ -n "$(places_with_arg "$key")" ]]; then
      found="$found $key"
    fi
  done
  echo "${found# }"
}

lab_unit_in_running() {
  local key found=""
  for key in $LAB_BOOT_KEYS; do
    if running_has_arg "$key"; then
      found="$found $key"
    fi
  done
  echo "${found# }"
}

remove_lab_keys() {
  grubby --update-kernel=ALL --remove-args="$LAB_BOOT_KEYS"
}

kernel_consoles() {
  cat /sys/class/tty/console/active
}

serial_console() {
  kernel_consoles | tr ' ' '\n' | grep -E '^ttyS[0-9]+$' | tail -n 1
}

default_target() {
  systemctl get-default 2>/dev/null
}

default_link_target() {
  basename "$(readlink -f /etc/systemd/system/default.target)"
}

default_target_problem() {
  local got
  got="$(default_target)"
  if [[ "$got" != "$BASELINE_TARGET" ]]; then
    echo "target по умолчанию $got, в исходном образе $BASELINE_TARGET"
  elif [[ "$(default_link_target)" != "$BASELINE_TARGET" ]]; then
    echo "симлинк default.target ведёт на $(default_link_target), а get-default говорит $got"
  fi
}

target_active() {
  systemctl is-active "$1" 2>/dev/null || true
}

allow_isolate() {
  systemctl show -p AllowIsolate --value "$1" 2>/dev/null
}

load_state() {
  systemctl show -p LoadState --value "$1" 2>/dev/null
}

isolate_problems() {
  local t found=""
  for t in $ISOLATABLE_TARGETS; do
    if [[ "$(allow_isolate "$t")" != "yes" ]]; then
      found="$found $t"
    fi
  done
  echo "${found# }"
}

core_target_problems() {
  local t found=""
  for t in $CORE_TARGETS; do
    if [[ "$(load_state "$t")" != "loaded" ]]; then
      found="$found $t"
    fi
  done
  echo "${found# }"
}

system_state() {
  systemctl is-system-running 2>/dev/null || true
}

analyze_total() {
  systemd-analyze 2>/dev/null | head -n 1
}

slowest_unit() {
  systemd-analyze blame 2>/dev/null | head -n 1 | sed 's/^ *//'
}

failed_units() {
  systemctl list-units --state=failed --no-legend --plain 2>/dev/null | awk '{ print $1 }'
}
