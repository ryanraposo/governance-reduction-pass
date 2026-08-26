#!/usr/bin/env bash
set -eEuo pipefail
NAME="governance-reduction-pass"
MODE="both"
RESTORE=false
AGENTS_ROOT="${AGENTS_HOME:-${HOME}/.agents}"
HERMES_ROOT="${HERMES_HOME:-${HOME}/.hermes}"
STATE_ROOT="${GOVERNANCE_REDUCTION_STATE_HOME:-${HOME}/.local/state/${NAME}}"

die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
warn(){ printf '[WARN] %s\n' "$*" >&2; }
usage(){ printf '%s\n' 'Usage: ./uninstall.sh [--hermes-only|--agents-only] [--restore]'; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --hermes-only) [ "$MODE" = both ] || die "choose one runtime scope"; MODE=hermes; shift ;;
    --agents-only) [ "$MODE" = both ] || die "choose one runtime scope"; MODE=agents; shift ;;
    --restore) RESTORE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

labels=(); targets=()
case "$MODE" in both|hermes) labels+=(hermes); targets+=("$HERMES_ROOT/skills/$NAME") ;; esac
case "$MODE" in both|agents) labels+=(agents); targets+=("$AGENTS_ROOT/skills/$NAME") ;; esac

latest_backup(){
  local label="$1" candidate
  [ -d "$STATE_ROOT/backups" ] || return 0
  while IFS= read -r candidate; do
    [ -f "$candidate/.${NAME}-managed" ] && continue
    printf '%s\n' "$candidate"
    return 0
  done < <(find "$STATE_ROOT/backups" -mindepth 2 -maxdepth 2 -type d -name "$label" -print 2>/dev/null | sort -r)
}

for i in "${!targets[@]}"; do
  target="${targets[$i]}"; label="${labels[$i]}"
  if [ -e "$target" ]; then
    [ -f "$target/.${NAME}-managed" ] || { warn "leaving unmanaged destination untouched: $target"; continue; }
    rm -rf -- "$target"
    printf '[OK] removed %s\n' "$target"
  fi
  if $RESTORE && [ ! -e "$target" ]; then
    backup="$(latest_backup "$label")"
    if [ -n "$backup" ] && [ -e "$backup" ]; then
      mkdir -p "$(dirname "$target")"
      mv "$backup" "$target"
      printf '[OK] restored %s\n' "$target"
    fi
  fi
done
