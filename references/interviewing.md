# Interviewing for governance reduction

Use interviews to recover current intent where repository evidence cannot distinguish a durable invariant from historical or incidental implementation.

## What to verify

Probe until you can separate:

- durable, product- or user-visible invariants that must remain protected;
- genuine external or public boundaries real consumers depend on;
- implementation details that were convenient at the time;
- historical failure modes that remain relevant from those that are obsolete;
- requirements that have quietly expired;
- constraints maintainers currently find painful;
- dimensions they expect and want to evolve soon;
- what they consider sacred versus freely replaceable.

## Ground questions in evidence

Prefer questions attached to a concrete file, assertion, schema field, workflow, or consumer path:

- “Who consumes this file or schema?”
- “What breaks if this disappears?”
- “Was this exact count, layout, or phase intentional, or just how the current implementation works?”
- “What regression caused this test to exist?”
- “Would you care if this implementation changed while preserving the observable behavior?”
- “What part of this subsystem do you expect to change next?”
- “Which constraints here would surprise you if an agent treated them as permanent?”
- “If we deleted this validation, what failure could escape?”
- “Is this documentation still operationally useful, or is Git now the better archive?”
- “If an agent rewrote this subsystem tomorrow while preserving every externally observable behavior and every real consumer contract, which of these artifacts would still need to exist, and why?”

Follow answers with concrete counterexamples when necessary. “We need this” is not yet an invariant. Ask what fails, for whom, where that dependency is observable, and whether a cheaper boundary can protect it.

## Evidence priority

When interview answers conflict with repository history, use:

1. current product / user intent
2. observable behavior and acceptance criteria
3. genuine external / public boundaries
4. current implementation
5. tests
6. historical documentation

## Record only the useful distillation

Treat answers as dated evidence, not a new constitution. Record the smallest useful statement, preferably in the PR body or the repository's existing authoritative decision surface.

Recommended shape:

```text
Intent evidence — YYYY-MM-DD
Evidence: <who/what was consulted and the concrete repository question>
Invariant retained: <smallest durable requirement, or “none”>
Freedom confirmed: <dimensions explicitly allowed to change>
Reason: <consumer, observable behavior, acceptance criterion, or current intent>
```

Do not create a new permanent governance file merely because an interview occurred. If the same question is revisited later, prefer the newer evidence when intent has changed.
