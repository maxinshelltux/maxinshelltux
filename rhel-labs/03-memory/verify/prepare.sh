#!/usr/bin/env bash
set -euo pipefail
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$MODULE_DIR/.." && pwd)"
# shellcheck source=scripts/verify/helpers.sh
source "$ROOT_DIR/scripts/verify/helpers.sh"
# shellcheck source=03-memory/lib.sh
source "$MODULE_DIR/lib.sh"
MEMHOG="$MODULE_DIR/memhog.py"

need_root
need_rhel10
for bin in free vmstat ps top pmap pgrep pkill systemd-run journalctl lsblk parted mkswap swapon swapoff; do
  need_bin "$bin"
done
[[ -x "$PYTHON" ]] || fail "нет $PYTHON"
require_file "$MEMHOG" "учебная программа memhog.py"
require_succeeds "memhog.py запускается" "$PYTHON" "$MEMHOG" --help
assert_eq "cgroup2fs" "$(stat -fc %T /sys/fs/cgroup)" "иерархия cgroup"
grep -qw memory /sys/fs/cgroup/cgroup.controllers || fail "контроллер memory в cgroup v2 не включён"

[[ "$(meminfo_mib MemTotal)" -ge 1200 ]] || fail "для модуля нужно не меньше 1200 МиБ памяти, есть $(meminfo_mib MemTotal)"
if [[ "$(cat /proc/sys/vm/overcommit_memory)" != 0 ]]; then
  warn "vm.overcommit_memory не 0 — часть 3 про эвристику будет выглядеть иначе"
fi

install -d -m 700 "$LAB_STATE_DIR"
if [[ ! -f "$LAB_STATE_DIR/baseline.txt" ]]; then
  {
    echo "# снято $(date -u '+%F %T UTC')"
    echo "## free -m"
    free -m
    echo "## swapon --show"
    swapon --show
    echo "## lsblk"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,MOUNTPOINTS
    echo "## /etc/fstab"
    cat /etc/fstab
  } > "$LAB_STATE_DIR/baseline.txt"
fi

ok "стенд готов: память $(meminfo_mib MemTotal) МиБ, доступно $(meminfo_mib MemAvailable) МиБ, swap $(meminfo_mib SwapTotal) МиБ, пустых дисков $(empty_disks | wc -l), раздел $LAB_SWAP_LABEL: $(lab_swap_dev | grep . || echo нет)"
