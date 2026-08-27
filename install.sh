#!/usr/bin/env bash
set -eEuo pipefail

NAME="governance-reduction-pass"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="both"
DRY_RUN=false
VERIFY_ONLY=false
AGENTS_ROOT="${AGENTS_HOME:-${HOME}/.agents}"
HERMES_ROOT="${HERMES_HOME:-${HOME}/.hermes}"
STATE_ROOT="${GOVERNANCE_REDUCTION_STATE_HOME:-${HOME}/.local/state/${NAME}}"

info(){ printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
ok(){ printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
usage(){ cat <<'USAGE'
Usage: ./install.sh [options]
  --hermes-only  Install only the Hermes-native skill
  --agents-only  Install only the portable Agent Skills copy
  --dry-run      Show destinations and verify source without mutation
  --verify-only  Verify this checkout without installing
  --help         Show this help
USAGE
}

cat <<'MASCOT'

▄ ▄▄ ▄▄▄▄      8<======
   ▄▀ 0x0 ▀▄────┘
    █  ───  █  I loves my gun
    █  [#]  █
     ▀▀   ▀▀

MASCOT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hermes-only) [ "$MODE" = both ] || die "choose one runtime scope"; MODE=hermes; shift ;;
    --agents-only) [ "$MODE" = both ] || die "choose one runtime scope"; MODE=agents; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verify-only) VERIFY_ONLY=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

if [ "${EUID:-$(id -u)}" -eq 0 ] && [ "${GOVERNANCE_REDUCTION_ALLOW_ROOT_TEST:-}" != 1 ]; then
  die "run as the logged-in user, not root"
fi
for cmd in python3 cp mv mkdir rm; do command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"; done

verify_source(){
  [ -f "$ROOT/SKILL.md" ] || die "missing SKILL.md"
  [ -f "$ROOT/runtimes/hermes-frontmatter.yaml" ] || die "missing Hermes metadata"
  [ -f "$ROOT/agents/openai.yaml" ] || die "missing OpenAI metadata"
  [ -x "$ROOT/scripts/scan-governance.py" ] || die "diagnostic scanner is not executable"
  python3 - "$ROOT" <<'PY'
from pathlib import Path
import re, sys
root=Path(sys.argv[1])
version=(root/'VERSION').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version): raise SystemExit('invalid VERSION')
skill=(root/'SKILL.md').read_text()
hermes=(root/'runtimes/hermes-frontmatter.yaml').read_text()
openai=(root/'agents/openai.yaml').read_text()
if not skill.startswith('---\n'): raise SystemExit('SKILL.md lacks frontmatter')
if '\nname: governance-reduction-pass\n' not in skill: raise SystemExit('canonical skill name mismatch')
if '\nname: governance-reduction-pass\n' not in hermes: raise SystemExit('Hermes skill name mismatch')
if f'\nversion: {version}\n' not in hermes: raise SystemExit('Hermes version mismatch')
if 'display_name: "Governance-Reduction Pass"' not in openai: raise SystemExit('OpenAI display identity mismatch')
PY
  python3 -m py_compile "$ROOT/scripts/scan-governance.py"
}

compose_hermes(){
  local out="$1"
  mkdir -p "$out"
  python3 - "$ROOT/SKILL.md" "$ROOT/runtimes/hermes-frontmatter.yaml" "$out/SKILL.md" <<'PY'
from pathlib import Path
import sys
skill=Path(sys.argv[1]).read_text()
front=Path(sys.argv[2]).read_text().rstrip()+"\n"
if not skill.startswith('---\n'):
    raise SystemExit('canonical SKILL.md frontmatter missing')
end=skill.find('\n---\n', 4)
if end < 0:
    raise SystemExit('canonical SKILL.md frontmatter is malformed')
body=skill[end+5:]
Path(sys.argv[3]).write_text(front + '\n' + body)
PY
  cp "$ROOT/VERSION" "$out/VERSION"
  cp -R "$ROOT/references" "$out/references"
  cp -R "$ROOT/scripts" "$out/scripts"
}

compose_agents(){
  local out="$1"
  mkdir -p "$out"
  cp "$ROOT/SKILL.md" "$out/SKILL.md"
  cp "$ROOT/VERSION" "$out/VERSION"
  cp -R "$ROOT/references" "$out/references"
  cp -R "$ROOT/scripts" "$out/scripts"
  cp -R "$ROOT/agents" "$out/agents"
}

verify_payload(){
  local label="$1" dir="$2"
  [ -f "$dir/SKILL.md" ] || die "$label payload missing SKILL.md"
  [ -x "$dir/scripts/scan-governance.py" ] || die "$label payload lost executable scanner"
  grep -q '^name: governance-reduction-pass$' "$dir/SKILL.md" || die "$label payload identity mismatch"
  if [ "$label" = hermes ]; then
    grep -q "^version: $(cat "$ROOT/VERSION")$" "$dir/SKILL.md" || die "Hermes payload version mismatch"
    [ ! -e "$dir/agents" ] || die "Hermes payload leaked OpenAI metadata"
  else
    [ -f "$dir/agents/openai.yaml" ] || die "portable payload missing OpenAI metadata"
  fi
}

verify_source
ok "source verified"
if $VERIFY_ONLY; then exit 0; fi

labels=()
targets=()
case "$MODE" in both|hermes) labels+=(hermes); targets+=("$HERMES_ROOT/skills/$NAME") ;; esac
case "$MODE" in both|agents) labels+=(agents); targets+=("$AGENTS_ROOT/skills/$NAME") ;; esac

info "Hermes is composed and verified first when included."
info "Install plan:"
for i in "${!targets[@]}"; do printf '  %-7s %s\n' "${labels[$i]}" "${targets[$i]}"; done
if $DRY_RUN; then
  ok "dry run complete; no skill homes, backups, locks, or staging directories were created"
  exit 0
fi

umask 077
mkdir -p "$STATE_ROOT/backups"
transaction="$STATE_ROOT/backups/$(date -u +%Y%m%dT%H%M%SZ).$$"
mkdir -p "$transaction"
lock="$STATE_ROOT/install.lock"
if ! mkdir "$lock" 2>/dev/null; then die "another install appears active: $lock"; fi
cleanup_lock(){ [ ! -d "$lock" ] || rm -rf -- "$lock"; }
trap cleanup_lock EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

stages=()
olds=()
committed=0
rollback(){
  local i target old failed stage
  warn "rolling back $committed committed target(s)"
  for ((i=committed-1; i>=0; i--)); do
    target="${targets[$i]}"; old="${olds[$i]}"
    if [ -e "$target" ]; then
      failed="$transaction/${labels[$i]}.failed"
      mv "$target" "$failed" || true
    fi
    if [ -n "$old" ] && [ -e "$old" ]; then mv "$old" "$target" || true; fi
  done
  for stage in "${stages[@]:-}"; do [ ! -e "$stage" ] || rm -rf -- "$stage"; done
}
on_error(){ local rc=$?; rollback; exit "$rc"; }
trap on_error ERR

for i in "${!targets[@]}"; do
  target="${targets[$i]}"
  parent="$(dirname "$target")"
  mkdir -p "$parent"
  stage="$(mktemp -d "$parent/.${NAME}.new.XXXXXX")"
  stages+=("$stage")
  if [ "${labels[$i]}" = hermes ]; then compose_hermes "$stage"; else compose_agents "$stage"; fi
  cat > "$stage/.${NAME}-managed" <<MARKER
managed-by=$NAME
version=$(cat "$ROOT/VERSION")
runtime=${labels[$i]}
MARKER
  verify_payload "${labels[$i]}" "$stage"
done

for i in "${!targets[@]}"; do
  target="${targets[$i]}"
  old=""
  if [ -e "$target" ]; then
    old="$transaction/${labels[$i]}"
    mv "$target" "$old"
    if [ ! -f "$old/.${NAME}-managed" ]; then warn "preserved unmanaged ${labels[$i]} destination -> $old"; fi
  fi
  olds+=("$old")
  mv "${stages[$i]}" "$target"
  committed=$((committed+1))
  verify_payload "${labels[$i]}" "$target"
  ok "${labels[$i]} installed and verified"
done

trap - ERR
printf 'installed=%s\nversion=%s\nmode=%s\n' "$(date -u +%FT%TZ)" "$(cat "$ROOT/VERSION")" "$MODE" > "$transaction/receipt"
cleanup_lock
trap - EXIT HUP INT TERM

printf '\nFreedom tool installed.\n'
for i in "${!targets[@]}"; do printf '  %-7s %s\n' "${labels[$i]}" "${targets[$i]}"; done
printf '  receipt %s\n' "$transaction/receipt"
printf '  Next: start a fresh agent session so the skill is rediscovered.\n'
