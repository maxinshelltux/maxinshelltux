#!/usr/bin/env bash
# shellcheck shell=bash

# shellcheck disable=SC2034
LAB_STATE_DIR=/var/lib/rhel-labs/02-kernel-modules
LAB_MODULE=dummy
LAB_DEP_MODULE=vxlan
LAB_DEP_HELPERS="ip6_udp_tunnel udp_tunnel"
LAB_PARAM_MODULE=brd
LAB_FILES=(
  /etc/modules-load.d/dummy.conf
  /etc/modules-load.d/brd.conf
  /etc/modprobe.d/brd.conf
  /etc/modprobe.d/lab-denylist.conf
  /etc/modules-load.d/rhel-labs-qa.conf
  /etc/modprobe.d/dummy.conf
  /etc/modprobe.d/zz-dummy.conf
)
LAB_RUN_FILES=(
  /run/modprobe.d/lab-dummy.conf
  /run/modprobe.d/zz-lab-dummy.conf
)
LAB_LINE_RE='^(dummy|brd|options dummy numdummies=[0-9]+|options brd rd_nr=[0-9]+( rd_size=[0-9]+)?|blacklist dummy|install dummy /bin/false)$'
LAB_KERNEL_ARG="modprobe.blacklist=dummy"

mod_loaded() { grep -q "^$1 " /proc/modules; }

mod_users() { awk -v m="$1" '$1 == m {print $3}' /proc/modules; }

mod_file() { modinfo -n "$1" 2>/dev/null; }

dummy_links() { ip -o link show type dummy 2>/dev/null | wc -l; }

effective_config() {
  modprobe -c | grep -E "^(options|blacklist|install) $1( |$)" || true
}

effective_options() {
  modprobe --show-depends "$1" 2>/dev/null | tail -n 1 | cut -d' ' -f3- | sed 's/ *$//'
}

last_option() {
  effective_options "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | tail -n 1
}

denylisted() { grep -qxE "blacklist $1" <<< "$(effective_config "$1")"; }

install_blocked() { grep -qE "^install $1 /bin/false" <<< "$(effective_config "$1")"; }

autoload_files() {
  local dir file
  for dir in /etc/modules-load.d /run/modules-load.d /usr/lib/modules-load.d; do
    for file in "$dir"/*.conf; do
      [[ -f "$file" ]] || continue
      if grep -qxE "[[:space:]]*$1[[:space:]]*" "$file"; then
        echo "$file"
      fi
    done
  done
}

cmdline_blacklist() {
  tr ' ' '\n' < /proc/cmdline | sed -n 's/^modprobe\.blacklist=//p'
}

boot_entries_with_lab_arg() {
  grubby --info=ALL | grep -c "^args=.*$LAB_KERNEL_ARG" || true
}

lab_file_state() {
  local file="$1" lines
  if [[ ! -e "$file" ]]; then
    echo "нет"
  elif [[ ! -s "$file" ]]; then
    echo "пустой"
  else
    lines="$(grep -cvE '^[[:space:]]*(#.*)?$' "$file" || true)"
    echo "строк: $lines"
  fi
}

lab_file_is_lab_owned() {
  local file="$1" line
  [[ -f "$file" && ! -L "$file" ]] || return 1
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ $LAB_LINE_RE ]] || return 1
  done < "$file"
  return 0
}

lab_files_with_content() {
  local file
  for file in "${LAB_FILES[@]}"; do
    if [[ -s "$file" ]]; then
      echo "$file"
    fi
  done
}

run_files_with_content() {
  local file
  for file in "${LAB_RUN_FILES[@]}"; do
    if [[ -s "$file" ]]; then
      echo "$file"
    fi
  done
}

brd_param() { cat "/sys/module/$LAB_PARAM_MODULE/parameters/$1" 2>/dev/null; }

unload_lab_modules() {
  local module
  for module in "$LAB_MODULE" "$LAB_PARAM_MODULE" "$LAB_DEP_MODULE" $LAB_DEP_HELPERS; do
    if mod_loaded "$module"; then
      modprobe -r "$module" 2>/dev/null || true
    fi
  done
}

reload_autoload() {
  systemctl reset-failed systemd-modules-load.service 2>/dev/null || true
  systemctl restart systemd-modules-load.service
}
