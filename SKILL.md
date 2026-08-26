---
name: governance-reduction-pass
description: >-
  Perform a governance-reduction pass on a codebase, branch, or pull request:
  recover real invariants and external boundaries, interview only where intent
  is materially uncertain, then delete or simplify tests, contracts, schemas,
  validators, documentation, generated artifacts, fixtures, workflows, and
  agent-facing machinery that fossilize incidental implementation. Use when
  repository governance has become architectural drag or refactoring is blocked
  by stale internal constraints. Do not use as generic code cleanup or to weaken
  genuine safety, regulatory, cryptographic, or public-consumer invariants.
---

# Governance-Reduction Pass

Perform the pass. Do not merely describe one unless the user explicitly asks for review-only output.

> **Preserve invariants. Liberate implementation.**

The goal is to make the repository easier and safer to change. Tests, contracts, schemas, validators, documentation, generated manifests, fixtures, workflows, and process machinery exist to support development. They must not fossilize the current implementation or force future work to preserve decisions that are no longer important.

A healthy test suite makes refactoring fearless, not illegal. A healthy contract describes a real boundary, not the internal anatomy of today's implementation. Documentation preserves useful understanding, not the repository or Git history in duplicate.

## Establish the real change surface

1. Inspect the current checkout, branch, pull request, or requested subsystem.
2. Preserve unrelated working-tree state and user changes.
3. Identify what the system actually consumes: packages, tools, runtime assets, serialized state, APIs, agents, people, CI, external integrations, and release machinery.
4. Trace usages before deleting anything. Search imports, reads, references, workflow invocations, loaders, package exports, docs links, prompt fragments, tool descriptions, and generated consumers.
5. When useful, run `python3 scripts/scan-governance.py .` as a **diagnostic** inventory. Its findings are leads, never proof that an artifact is wrong.
6. Determine a representative pure-implementation change and note how many unrelated artifacts it currently forces the developer to touch.

## Recover intent before preserving unclear governance

When the purpose of a constraint is unclear and the answer could materially change what survives, recover current intent before constitutionalizing it.

Interview relevant maintainers, users, consumers, agents, or stakeholders when they are available. A primary job of interviewing is **thorough verification of invariants**. Do not accept surface statements at face value: probe until you can distinguish durable product or user invariants, genuine external boundaries, incidental implementation, obsolete failure modes, expired requirements, painful constraints, expected evolution, and what is actually sacred.

Read `references/interviewing.md` for the evidence protocol and grounded question bank.

Interview only where uncertainty matters. Do not require human confirmation for obvious cleanup, mechanical tracing, or changes whose intent is already clear from current product behavior and real consumers.

Treat interview answers as evidence of current intent, not as new permanent governance. Distill the verified invariant—or the explicit freedom to evolve—concisely with the date. If the same question is asked later and intent has drifted, prefer the newer answer.

When evidence conflicts, use this priority:

1. current product / user intent
2. observable behavior and acceptance criteria
3. genuine external / public boundaries
4. current implementation
5. tests
6. historical documentation

Tests and docs are evidence. They are not constitutional law.

## Evaluate every governance artifact

For every test, contract, schema, validator, fixture, generated artifact, workflow, checklist, prompt fragment, tool description, and document, ask:

1. Does this prevent a costly or user-visible regression?
2. Does another real consumer—system, package, agent, person, or external integration—require this boundary?
3. Would deleting this make an important architectural or product decision genuinely unknowable?

If all three answers are **no**, strongly prefer deleting the artifact or demoting its assertion from governance to diagnostics.

Git is already the archive. Do not keep historical machinery merely to prove that an old architecture stays gone.

## Tests

Prefer tests of capabilities, invariants, and observable behavior, such as:

- the asset loads;
- the feature produces the intended result;
- a guarded operation leaves source data intact;
- a public API accepts and returns its documented semantics;
- the packaged artifact can actually be consumed;
- interruption, failure, or recovery behaves correctly.

Treat these with suspicion unless a real consumer proves they matter:

- exact internal object counts;
- exact phase counts;
- exact directory or file layouts;
- today's joint, clip, component, node, or track count;
- today's implementation strategy;
- snapshots of large incidental structures;
- tests proving deleted legacy architecture remains deleted;
- tests whose effective assertion is only “the implementation did not change.”

Diagnostics may report implementation details without turning them into pass/fail requirements. Delete obsolete tests instead of contorting new architecture to satisfy them.

## Contracts

Contracts belong at real boundaries, including:

- agent ↔ tool;
- frontend ↔ backend;
- package ↔ consumer;
- renderer ↔ runtime asset;
- serialized persisted state that must remain readable;
- external or public API.

Inside a rapidly evolving subsystem, avoid formalizing implementation details prematurely. A contract should contain the smallest stable semantic surface necessary for interoperability.

Do not make topology, internal phases, exact object counts, private helper structure, incidental metadata, generated measurements, or today's algorithm contractual unless an actual consumer demonstrably relies on them.

Prefer “Consumer can resolve semantic animation by name” over “Asset contains exactly N joints, M clips, and K tracks using this weighting strategy.”

## Documentation

Reduce duplicated truth. Prefer a small hierarchy:

- `README.md` — what this is and how to use or run it;
- a concise architecture document only when architecture genuinely needs explanation;
- focused reference docs for real interfaces;
- current planning or state only while it has active operational value.

Do not maintain overlapping explanations of the same architecture across README, schemas, contracts, prompts, fixtures, tests, manifests, and validators. Choose one authoritative representation and reference it.

Delete stale plans and historical explanations when Git already preserves them. When useful, prefer a deliberately small “Current invariants and free dimensions” note that changes only when the protected set changes.

## Generated artifacts and schemas

Generated files have maintenance cost. Keep them only when something actually consumes them.

Do not generate manifests, checksums, schemas, reports, snapshots, or metadata merely because they make the repository appear rigorous. Ask what decision each artifact enables. If removing it changes no meaningful decision, remove it.

## Validators

Prefer one meaningful validation path over several partially overlapping validators.

Separate:

- **errors** — a required capability cannot be provided;
- **diagnostics** — interesting observations that may guide improvement;
- **preferences** — characteristics of the current implementation.

Promote a property from diagnostic to error only when either:

- a real consumer or acceptance criterion depends on it; or
- violating it has caused a costly, user-visible failure that cannot be caught more cheaply.

“It would be nice if the implementation stayed this way” is never sufficient.

## Workflows

Collapse overlapping CI and workflow machinery. Keep the smallest verification surface that gives confidence in important behavior. Avoid several jobs that independently rediscover the same facts through different scripts.

## Agent-facing repositories

Agents interpret repository artifacts as intentional constraints. Obsolete tests, schemas, validators, fixtures, manifests, prompt fragments, tool descriptions, and checklists are therefore more harmful than ordinary clutter: they actively bias future implementation and search.

For every agent-readable artifact, ask:

> Would an agent reasonably conclude that this shape is required for correctness?

If yes, and the three evaluation questions are all negative, delete or demote it. When an implementation detail remains useful as guidance, mark it explicitly non-binding.

## High-stakes domains

In safety-critical, regulatory, cryptographic, or externally contracted domains, the cost of a false negative can be extreme. Preserve the true invariant and document the external source of the constraint so future maintainers know it is not an accident of the current implementation.

Even here, prefer the smallest possible formalization of the real invariant.

## Measure architectural drag

For a representative pure-implementation change, ask:

> How many unrelated artifacts must change merely because the implementation changed?

Aim for:

- implementation;
- a few meaningful behavioral tests;
- documentation only when user-facing behavior or a real decision changed.

Treat changes that force edits across schemas, manifests, snapshots, fixtures, validators, several documents, generated reports, and unrelated tests as evidence of architectural drag.

Useful post-pass metrics include:

- files or artifacts touched by a pure implementation change;
- tests asserting only internal counts, exact layouts, or “legacy is gone”;
- overlapping validators or CI jobs;
- generated artifacts no live consumer reads.

These metrics are diagnostics, not targets to game.

## Perform the pass

1. Inspect the current branch or PR and understand what the system actually consumes.
2. Identify uncertain constraints where recovered human or consumer intent could materially affect what should survive.
3. Interview relevant maintainers, users, consumers, agents, or stakeholders where useful. Ask targeted questions tied to concrete repository evidence and thoroughly verify claimed invariants.
4. Distill answers into actual invariants, boundaries, acceptance criteria, and areas intentionally free to evolve. Date the distillations.
5. Identify tests, contracts, docs, schemas, generated artifacts, fixtures, validators, workflows, prompts, and tooling that encode incidental implementation or history.
6. Trace usages before deleting anything.
7. Delete or simplify unnecessary governance.
8. Update consumers so deleted machinery is genuinely gone; do not leave compatibility debris unless it serves a real purpose.
9. Convert useful implementation measurements into diagnostics where appropriate.
10. Preserve strong behavioral and invariant checks.
11. Collapse duplicated validators, workflows, and documentation.
12. Run the smallest meaningful verification available.
13. Sweep for stale references to deleted concepts or files, including agent-facing surfaces such as prompts, skills, tool descriptions, fixture loaders, and generated examples.
14. Rewrite the PR body or active documentation so it describes the resulting system, not the archaeology that produced it.
15. Include an explicit **Freedom recovered / Invariants retained** section and state where interview evidence materially changed the result.

Be willing to delete substantial amounts of apparently responsible engineering when that engineering has become an obstacle to responsible change.

Do not optimize for fewer files as an aesthetic goal. Optimize for:

> **maximum freedom to evolve + strong protection of what actually matters**

## Completion report

Finish with a concise evidence-backed report containing:

### Freedom recovered / Invariants retained

- **Invariants retained:** the behavioral, product, safety, or consumer requirements still protected.
- **Freedom recovered:** implementation dimensions no longer falsely governed.
- **Deleted / simplified governance:** the important artifacts removed, collapsed, or demoted.
- **Interview evidence:** only decisions materially changed by recovered intent, with dates.
- **Verification:** the smallest meaningful checks actually run and their outcomes.
- **Remaining drag:** any governance kept despite uncertainty, with the concrete reason it remains.

Do not claim success from green commands alone when observable behavior or a real consumer can be checked directly.
