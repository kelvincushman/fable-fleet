# Plan: <feature name> — Phase <n>

**Goal (2-3 sentences):**
**Out of scope (explicit):**
**Phase gate:** human approval required before dispatch.

## Task table

| Task-id | Title | Owner role   | Risk | Depends on |
|---------|-------|--------------|------|------------|
| T1      |       | opus-coder   | high | —          |
| T2      |       | codex-coder  | med  | —          |
| T3      |       | glm-spinner  | low  | T2         |

## Task detail (one block per task)

### T<n>: <title>
**Owner:** <role>
**Files touched (exhaustive — scopes implementation AND review):**
- path/one
- path/two

**Spec (what to build, precisely):**

**Acceptance criteria (machine-checkable — the verifier runs these verbatim):**
| # | Command | Expected |
|---|---------|----------|
| 1 | `bun test src/foo.test.ts` | exit 0 |
| 2 | `curl -s localhost:3000/health` | `{"ok":true}` |
| 3 | `test -f src/generated/schema.ts && echo yes` | `yes` |

**Escalation triggers (ask, don't guess):**
- <known ambiguity 1>

## Verification task (always last)

### TV: Phase verification
**Owner:** qwen-verifier
**Inputs:** this plan + all audit-*.md files
**Output:** feature-research/<task>/phase-report.md
