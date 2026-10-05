#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

ok()   { printf '[OK] %s\n'   "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; return 1; }

need_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || fail "нужен root: запусти через sudo"
}

need_bin() {
  command -v "$1" >/dev/null 2>&1 || fail "не найдена утилита: $1"
}

need_rhel10() {
  grep -q 'Red Hat Enterprise Linux release 10' /etc/redhat-release 2>/dev/null \
    || fail "модуль рассчитан на RHEL 10 (см. /etc/redhat-release)"
}

require_file() {
  local f="$1" desc="${2:-$1}"
  [[ -e "$f" ]] || fail "нет пути: $desc ($f)"
}

assert_eq() {
  local exp="$1" act="$2" desc="$3"
  [[ "$exp" == "$act" ]] || fail "$desc: ожидалось '$exp', получено '$act'"
}

assert_ne() {
  local nexp="$1" act="$2" desc="$3"
  [[ "$nexp" != "$act" ]] || fail "$desc: значение совпало с '$nexp', а не должно"
}

require_succeeds() {
  local desc="$1"; shift
  "$@" >/dev/null 2>&1 || fail "$desc (команда упала: $*)"
}

require_fails() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    fail "$desc (команда прошла, ожидался отказ)"
  fi
}
