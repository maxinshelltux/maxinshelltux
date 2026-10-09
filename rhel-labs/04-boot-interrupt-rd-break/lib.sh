#!/usr/bin/env bash
# shellcheck shell=bash

# shellcheck disable=SC2034
LAB_STATE_DIR=/var/lib/rhel-labs/04-boot-interrupt-rd-break
LAB_BOOT_KEYS="rd.break enforcing emergency lab"
LAB_MIN_GRUB_TIMEOUT=3
LAB_INITRAMFS_PATHS="usr/sbin/sulogin usr/bin/dracut-emergency usr/sbin/chroot usr/bin/mount"
GRUB_DEFAULTS=/etc/default/grub
GRUB_CFG=/boot/grub2/grub.cfg

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

default_kernel() { grubby --default-kernel; }
running_kernel() { echo "/boot/vmlinuz-$(uname -r)"; }

kernel_version() {
  basename "$1" | sed 's/^vmlinuz-//'
}

entry_args() {
  grubby --info="$1" | sed -n 's/^args="\(.*\)"$/\1/p' | head -n 1
}

grub_default_value() {
  (
    set +u
    # shellcheck source=/dev/null
    source "$GRUB_DEFAULTS"
    printf '%s\n' "${!1}"
  )
}

grubenv_value() {
  grub2-editenv list | sed -n "s/^$1=//p"
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
  if words_have "$key" < /etc/kernel/cmdline; then
    found="$found /etc/kernel/cmdline"
  fi
  if grub_default_value GRUB_CMDLINE_LINUX | words_have "$key"; then
    found="$found GRUB_CMDLINE_LINUX"
  fi
  echo "${found# }"
}

lab_keys_in_config() {
  local key found=""
  for key in $LAB_BOOT_KEYS; do
    if [[ -n "$(places_with_arg "$key")" ]]; then
      found="$found $key"
    fi
  done
  echo "${found# }"
}

lab_keys_in_running() {
  local key found=""
  for key in $LAB_BOOT_KEYS; do
    if running_has_arg "$key"; then
      found="$found $key"
    fi
  done
  echo "${found# }"
}

configured_words() {
  { entry_args "$(running_kernel)"; grubenv_value tuned_params; } \
    | tr ' ' '\n' | grep -vE '^(\$.*|ro|root=.*)?$' | sort -u || true
}

running_words() {
  tr ' ' '\n' < /proc/cmdline | grep -vE '^((BOOT_IMAGE|root)=.*|ro)?$' | sort -u || true
}

words_only_running() {
  comm -13 <(configured_words) <(running_words) | tr '\n' ' ' | sed 's/ $//'
}

words_only_configured() {
  comm -23 <(configured_words) <(running_words) | tr '\n' ' ' | sed 's/ $//'
}

kernel_consoles() {
  cat /sys/class/tty/console/active
}

serial_console() {
  kernel_consoles | tr ' ' '\n' | grep -E '^ttyS[0-9]+$' | tail -n 1
}

grub_cfg_timeout() {
  sed -n 's/^ *set timeout=\([0-9][0-9]*\)$/\1/p' "$GRUB_CFG" | head -n 1
}

grub_cfg_has_serial() {
  grep -qE '^serial( |$)' "$GRUB_CFG" \
    && grep -qE '^terminal_input .*serial' "$GRUB_CFG" \
    && grep -qE '^terminal_output .*serial' "$GRUB_CFG"
}

grub_menu_problem() {
  local timeout
  timeout="$(grub_cfg_timeout)"
  if ! grub_cfg_has_serial; then
    echo "в $GRUB_CFG нет вывода меню в последовательный порт (строки serial, terminal_input, terminal_output)"
  elif [[ -z "$timeout" || "$timeout" -lt "$LAB_MIN_GRUB_TIMEOUT" ]]; then
    echo "меню GRUB ждёт ${timeout:-0} с, нужно не меньше $LAB_MIN_GRUB_TIMEOUT"
  elif [[ "$timeout" != "$(grub_default_value GRUB_TIMEOUT)" ]]; then
    echo "GRUB_TIMEOUT=$(grub_default_value GRUB_TIMEOUT) в $GRUB_DEFAULTS, а в $GRUB_CFG timeout=$timeout: конфигурацию не пересобрали"
  fi
}

initramfs_image() {
  echo "/boot/initramfs-$(kernel_version "$1").img"
}

initramfs_listing() {
  lsinitrd "$1" 2>/dev/null
}

listing_has() {
  grep -qE "[[:space:]]$2\$" <<< "$1"
}

initramfs_root_password() {
  lsinitrd "$1" -f etc/passwd 2>/dev/null | awk -F: '$1 == "root" { print ($2 == "" ? "empty" : "set") }'
}

shadow_context() {
  stat -c %C /etc/shadow
}

shadow_label_problem() {
  restorecon -n -v /etc/shadow 2>&1
}

root_password_status() {
  passwd -S root | awk '{ print $2 }'
}

root_password_words() {
  case "$(root_password_status)" in
    P) echo "задан" ;;
    L) echo "заблокирован" ;;
    NP) echo "пустой" ;;
    *) echo "неизвестно" ;;
  esac
}

remove_lab_keys() {
  grubby --update-kernel=ALL --remove-args="$LAB_BOOT_KEYS"
}
