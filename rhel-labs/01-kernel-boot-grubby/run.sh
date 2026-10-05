#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=01-kernel-boot-grubby/lib.sh
source "$MODULE_DIR/lib.sh"

need_root
need_bin grubby
need_bin grub2-editenv

RUNNING="/boot/vmlinuz-$(uname -r)"
DEFAULT="$(default_kernel)"

echo "=== Работающее ядро ==="
echo "uname -r:      $(uname -r)"
echo "/proc/cmdline: $(cat /proc/cmdline)"
echo

echo "=== Ядро по умолчанию (следующая загрузка) ==="
echo "kernel:      $DEFAULT"
echo "index:       $(default_index)"
echo "title:       $(grubby --default-title)"
echo "saved_entry: $(grubenv_value saved_entry)"
NEXT_ENTRY="$(grubenv_value next_entry)"
echo "next_entry:  ${NEXT_ENTRY:-<не задан>}"
echo

echo "=== Записи загрузчика (D = по умолчанию, R = работает сейчас) ==="
while IFS= read -r kernel; do
  marks=""
  [[ "$kernel" == "$DEFAULT" ]] && marks="${marks}D"
  [[ "$kernel" == "$RUNNING" ]] && marks="${marks}R"
  printf '[%-2s] index=%s %s\n' "$marks" "$(index_of_kernel "$kernel")" "$kernel"
  printf '     args: %s\n' "$(entry_args "$kernel")"
done < <(kernels)
echo

echo "=== Шаблоны параметров для будущих ядер ==="
echo "/etc/kernel/cmdline: $(cat /etc/kernel/cmdline)"
echo "GRUB_CMDLINE_LINUX:  $(grub_default_cmdline)"
echo

echo "=== Нужна ли перезагрузка ==="
NEED_REBOOT=0
if [[ "$RUNNING" != "$DEFAULT" ]]; then
  echo "- работает $(uname -r), а по умолчанию $(kernel_version "$DEFAULT")"
  NEED_REBOOT=1
fi

CONFIGURED="$({ entry_args "$DEFAULT"; grubenv_value tuned_params; } | tr ' ' '\n' | grep -vE '^(\$.*)?$' | sort -u || true)"
ACTIVE="$(tr ' ' '\n' < /proc/cmdline | grep -vE '^(BOOT_IMAGE|root)=' | sort -u || true)"
ONLY_CONFIGURED="$(comm -23 <(echo "$CONFIGURED") <(echo "$ACTIVE") | tr '\n' ' ')"
ONLY_ACTIVE="$(comm -13 <(echo "$CONFIGURED") <(echo "$ACTIVE") | tr '\n' ' ')"
if [[ -n "${ONLY_CONFIGURED// /}" ]]; then
  echo "- в записи по умолчанию есть, а в /proc/cmdline нет: $ONLY_CONFIGURED"
  NEED_REBOOT=1
fi
if [[ -n "${ONLY_ACTIVE// /}" ]]; then
  echo "- в /proc/cmdline есть, а в записи по умолчанию нет: $ONLY_ACTIVE"
  NEED_REBOOT=1
fi

if [[ "$NEED_REBOOT" -eq 1 ]]; then
  warn "конфигурация и работающая система расходятся — изменения вступят в силу после systemctl reboot"
else
  ok "работающая система совпадает с конфигурацией загрузчика"
fi
