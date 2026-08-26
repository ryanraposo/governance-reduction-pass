#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf '[1/5] syntax\n'
bash -n install.sh uninstall.sh tests/run.sh
python3 -m py_compile scripts/scan-governance.py

printf '[2/5] package identity\n'
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re, sys
root=Path(sys.argv[1])
version=(root/'VERSION').read_text().strip()
skill=(root/'SKILL.md').read_text()
hermes=(root/'runtimes/hermes-frontmatter.yaml').read_text()
openai=(root/'agents/openai.yaml').read_text()
assert re.fullmatch(r'\d+\.\d+\.\d+', version)
assert '\nname: governance-reduction-pass\n' in skill
assert '\nname: governance-reduction-pass\n' in hermes
assert f'\nversion: {version}\n' in hermes
assert 'display_name: "Governance-Reduction Pass"' in openai
combined=''.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file() and '.git' not in p.parts)
assert not re.search(r'\{\{(?:DISPLAY_NAME|SKILL_NAME|DESCRIPTION)\}\}', combined)
PY

printf '[3/5] diagnostic scanner behavior\n'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/tests" "$tmp/docs"
cat > "$tmp/tests/widget.test.js" <<'JS'
expect(graph.nodes.length).toBe(17)
JS
cat > "$tmp/docs/architecture.md" <<'MD'
The validator should preserve the exact directory layout.
MD
python3 scripts/scan-governance.py "$tmp" --json > "$tmp/out.json"
python3 - "$tmp/out.json" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data['diagnostic_only'] is True
assert any(a['path']=='tests/widget.test.js' and 'test' in a['categories'] for a in data['artifacts'])
assert any(f['kind']=='exact-count-assertion' for f in data['findings'])
PY

printf '[4/5] non-mutating installer verification\n'
export GOVERNANCE_REDUCTION_ALLOW_ROOT_TEST=1
./install.sh --verify-only
./install.sh --dry-run >/dev/null

printf '[5/5] isolated dual-runtime install\n'
export HERMES_HOME="$tmp/hermes"
export AGENTS_HOME="$tmp/agents"
export GOVERNANCE_REDUCTION_STATE_HOME="$tmp/state"
mkdir -p "$HERMES_HOME/skills/governance-reduction-pass" "$AGENTS_HOME/skills/governance-reduction-pass"
printf 'original hermes\n' > "$HERMES_HOME/skills/governance-reduction-pass/sentinel.txt"
printf 'original agents\n' > "$AGENTS_HOME/skills/governance-reduction-pass/sentinel.txt"
./install.sh >/dev/null
[ -f "$HERMES_HOME/skills/governance-reduction-pass/SKILL.md" ]
[ ! -e "$HERMES_HOME/skills/governance-reduction-pass/agents" ]
[ -f "$AGENTS_HOME/skills/governance-reduction-pass/agents/openai.yaml" ]
grep -q '^version: 1.0.0$' "$HERMES_HOME/skills/governance-reduction-pass/SKILL.md"
# Reinstall once: original unmanaged backups must remain recoverable.
./install.sh >/dev/null
./uninstall.sh --restore >/dev/null
[ "$(cat "$HERMES_HOME/skills/governance-reduction-pass/sentinel.txt")" = 'original hermes' ]
[ "$(cat "$AGENTS_HOME/skills/governance-reduction-pass/sentinel.txt")" = 'original agents' ]

printf 'All meaningful package checks passed.\n'
