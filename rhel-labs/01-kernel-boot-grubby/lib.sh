#!/usr/bin/env bash
# shellcheck shell=bash

LAB_PARAM_KEYS="transparent_hugepage quiet loglevel"
# shellcheck disable=SC2034
LAB_STATE_DIR=/var/lib/rhel-labs/01-kernel-boot-grubby

kernels() {
  find /boot -maxdepth 1 -name 'vmlinuz-*' ! -name '*rescue*' | sort -V
}

newest_kernel() { kernels | tail -n 1; }
oldest_kernel() { kernels | head -n 1; }
kernel_count() { kernels | wc -l; }

entry_args() {
  grubby --info="$1" | sed -n 's/^args="\(.*\)"$/\1/p' | head -n 1
}

words_have() {
  tr ' ' '\n' | grep -qxE "$1(=.*)?"
}

entry_has_arg() {
  entry_args "$1" | words_have "$2"
}

entries_with_arg() {
  local kernel count=0
  while IFS= read -r kernel; do
    if entry_has_arg "$kernel" "$1"; then
      count=$((count + 1))
    fi
  done < <(kernels)
  echo "$count"
}

running_has_arg() {
  words_have "$1" < /proc/cmdline
}

kernel_cmdline_has() {
  words_have "$1" < /etc/kernel/cmdline
}

grub_default_cmdline() {
  sed -n 's/^GRUB_CMDLINE_LINUX="\(.*\)"$/\1/p' /etc/default/grub
}

grub_default_has() {
  grub_default_cmdline | words_have "$1"
}

default_kernel() { grubby --default-kernel; }
default_index() { grubby --default-index; }

index_of_kernel() {
  grubby --info="$1" | sed -n 's/^index=//p' | head -n 1
}

kernel_version() {
  basename "$1" | sed 's/^vmlinuz-//'
}

grubenv_value() {
  grub2-editenv list | sed -n "s/^$1=//p"
}

lab_params_in_config() {
  local key found=""
  for key in $LAB_PARAM_KEYS; do
    if [[ "$(entries_with_arg "$key")" -gt 0 ]]; then
      found="$found $key"
    fi
  done
  echo "${found# }"
}

lab_params_in_running() {
  local key found=""
  for key in $LAB_PARAM_KEYS; do
    if running_has_arg "$key"; then
      found="$found $key"
    fi
  done
  echo "${found# }"
}

remove_lab_params() {
  grubby --update-kernel=ALL --remove-args="$LAB_PARAM_KEYS"
}
