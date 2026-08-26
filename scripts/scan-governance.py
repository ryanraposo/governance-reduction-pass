#!/usr/bin/env python3
"""Non-binding governance inventory for a repository.

This tool finds likely governance artifacts and suspicious implementation-coupled
assertions. It never decides what should be deleted and returns success when it
finds candidates; findings are diagnostics for a human/agent to investigate.
"""
from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

IGNORE_DIRS = {
    ".git", ".hg", ".svn", ".idea", ".vscode", "node_modules", "vendor",
    "dist", "build", "target", ".next", ".cache", ".venv", "venv", "__pycache__",
}
TEXT_SUFFIXES = {
    ".py", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".go", ".rs", ".java",
    ".kt", ".kts", ".rb", ".php", ".cs", ".cpp", ".cc", ".c", ".h", ".hpp",
    ".sh", ".bash", ".zsh", ".yaml", ".yml", ".json", ".toml", ".md", ".rst",
}

CATEGORY_RULES = [
    ("workflow", lambda p: ".github/workflows" in p.as_posix() or p.name in {"Jenkinsfile", ".gitlab-ci.yml"}),
    ("fixture", lambda p: any(part.lower() in {"fixture", "fixtures", "testdata", "golden"} for part in p.parts)),
    ("schema", lambda p: "schema" in p.name.lower() or "openapi" in p.name.lower() or "swagger" in p.name.lower()),
    ("contract", lambda p: "contract" in p.name.lower()),
    ("validator", lambda p: any(token in p.name.lower() for token in ("validate", "validator", "verification", "verify"))),
    ("generated", lambda p: p.suffix == ".snap" or any(token in p.name.lower() for token in ("generated", "manifest", "snapshot"))),
    ("test", lambda p: any(part.lower() in {"test", "tests", "spec", "specs", "__tests__"} for part in p.parts)
        or re.search(r"(?:^|[._-])(test|spec)(?:[._-]|$)", p.name.lower()) is not None),
    ("documentation", lambda p: p.suffix.lower() in {".md", ".rst"} or any(part.lower() in {"docs", "doc"} for part in p.parts)),
]

SUSPICION_RULES = [
    (
        "exact-count-assertion",
        re.compile(r"(?i)(?:assert|expect|should|must).*?(?:length|len\s*\(|count|size|tracks?|clips?|joints?|phases?|components?|nodes?).{0,50}(?:==|===|=|toBe\s*\(|equal\s*\(|equals\s*\()?\s*\d+"),
        "Assertion appears to pin an exact count; verify a real consumer needs that number.",
    ),
    (
        "legacy-absence-assertion",
        re.compile(r"(?i)(?:assert|expect|should|must).{0,80}(?:legacy|deprecated|removed|deleted|old[-_ ]architecture).{0,80}(?:absent|gone|missing|not\s+exist|false|null|undefined)"),
        "Assertion may exist only to prove historical architecture stays gone.",
    ),
    (
        "snapshot-coupling",
        re.compile(r"(?i)(?:toMatchSnapshot|snapshot[_ -]?test|golden[_ -]?(?:file|test)|assert[_ -]?snapshot)"),
        "Snapshot/golden test may govern a large incidental structure; inspect its semantic value.",
    ),
    (
        "exact-layout-language",
        re.compile(r"(?i)(?:must|should|assert|expect).{0,60}(?:exact(?:ly)?|fixed).{0,30}(?:path|directory|folder|layout|structure|order|phase)"),
        "Text may elevate current layout or ordering into a requirement.",
    ),
]

@dataclass
class Artifact:
    path: str
    categories: list[str]

@dataclass
class Finding:
    path: str
    line: int
    kind: str
    excerpt: str
    note: str


def iter_files(root: Path) -> Iterable[Path]:
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS and not d.startswith(".skill-ux-run")]
        base = Path(current)
        for name in files:
            yield base / name


def classify(path: Path, root: Path) -> list[str]:
    rel = path.relative_to(root)
    return [name for name, rule in CATEGORY_RULES if rule(rel)]


def read_text(path: Path, max_bytes: int) -> str | None:
    try:
        if path.stat().st_size > max_bytes:
            return None
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {"Jenkinsfile", "Makefile"}:
            return None
        return path.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeError):
        return None


def scan(root: Path, max_bytes: int) -> tuple[list[Artifact], list[Finding]]:
    artifacts: list[Artifact] = []
    findings: list[Finding] = []
    for path in iter_files(root):
        categories = classify(path, root)
        if categories:
            artifacts.append(Artifact(path.as_posix().removeprefix(root.as_posix().rstrip("/") + "/"), categories))

        text = read_text(path, max_bytes)
        if text is None:
            continue
        rel = path.relative_to(root).as_posix()
        for number, line in enumerate(text.splitlines(), 1):
            compact = line.strip()
            if not compact or len(compact) > 800:
                continue
            for kind, regex, note in SUSPICION_RULES:
                if regex.search(compact):
                    findings.append(Finding(rel, number, kind, compact[:220], note))
    artifacts.sort(key=lambda item: item.path)
    findings.sort(key=lambda item: (item.path, item.line, item.kind))
    return artifacts, findings


def render_markdown(root: Path, artifacts: list[Artifact], findings: list[Finding]) -> str:
    counts: dict[str, int] = {}
    for artifact in artifacts:
        for category in artifact.categories:
            counts[category] = counts.get(category, 0) + 1

    lines = [
        "# Governance diagnostic",
        "",
        f"Root: `{root}`",
        "",
        "> Diagnostic only. Every candidate still requires usage tracing and invariant reasoning.",
        "",
        "## Inventory",
        "",
    ]
    if counts:
        for category, count in sorted(counts.items()):
            lines.append(f"- **{category}:** {count}")
    else:
        lines.append("No conventional governance artifacts detected.")

    lines.extend(["", "## Suspicious coupling", ""])
    if findings:
        for item in findings:
            lines.append(f"- `{item.path}:{item.line}` — **{item.kind}** — {item.note}")
            lines.append(f"  - `{item.excerpt.replace('`', "'")}`")
    else:
        lines.append("No heuristic coupling patterns detected.")

    lines.extend([
        "",
        "## Next questions",
        "",
        "For each candidate: who consumes it, what failure escapes if it disappears, and would the requirement survive a rewrite that preserved observable behavior?",
    ])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Inventory repository governance without turning heuristics into policy.")
    parser.add_argument("root", nargs="?", default=".", help="repository root (default: current directory)")
    parser.add_argument("--json", action="store_true", help="emit JSON instead of Markdown")
    parser.add_argument("--max-bytes", type=int, default=1_000_000, help="maximum text file size to inspect")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        parser.error(f"not a directory: {root}")

    artifacts, findings = scan(root, args.max_bytes)
    if args.json:
        print(json.dumps({
            "root": str(root),
            "diagnostic_only": True,
            "artifacts": [asdict(item) for item in artifacts],
            "findings": [asdict(item) for item in findings],
        }, indent=2))
    else:
        print(render_markdown(root, artifacts, findings), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
