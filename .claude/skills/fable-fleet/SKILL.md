---
name: fable-fleet
description: Use when the user wants to run the Fable Fleet — kick off a multi-model orchestration phase, coordinate specialist model workers via Orca, or says things like "run the fleet", "start a fleet phase", "orchestrate this with the fleet", "use the fleet to build/fix X", or "fleet this".
---

# Fable Fleet — run a coordination phase

Invoking this makes THIS session the fleet **coordinator**: you plan and delegate the user's task across specialist model workers (Opus = hard slices, Codex = bulk, GLM = parallel work + scouting) and a cross-family Qwen-on-Groq verifier, all through the Orca CLI. You consume plans, audits, and verdicts — **you never edit code, open diffs, or read raw source yourself.**

**REQUIRED CONTRACT:** Read `orca/roles/coordinator.md` and follow it exactly — it holds the full phase loop, the exact dispatch commands, the retry ladder, and the hard rules. This skill only gets you started; that file is the source of truth.

## Pre-flight (in order, before planning)

1. **Kit present?** Confirm `orca/roles/coordinator.md` exists in this repo. If it doesn't, the fleet isn't installed here — stop and tell the user to add the `orca/` kit (github.com/kelvincushman/fable-fleet).
2. **Runtime up?** Run `orca status`. If it isn't `runtimeReachable: true`, restart the Orca serve process, then re-check. (If a documented command returns "Unsupported SSH Orca CLI command", you're on the thin relay — use the full CLI path.)
3. **Cost check.** The coordinator is meant to run on **Fable 5** (cheap brain, cheap loop). If this session is a pricier model, say so — routine coordination on an expensive model is exactly the token-sink the fleet exists to kill — then proceed only if the user confirms.

## Then run the phase (per coordinator.md)

1. Write `feature-research/<task>/plan.md` — every task with an explicit **Files-touched** list and a **runnable acceptance test**.
2. **Gate the plan to the user and wait for approval** before dispatching anything.
3. Dispatch to the right workers by cost routing, `scope-check.sh` each result, then dispatch the Qwen verifier.
4. Report the `ship` / `fix first` verdict. On `ship`, append progress and reset for the next phase; on `fix first`, follow the retry ladder (retry → diagnostic panel → human tiebreaker).

## The one rule

Never write or edit code, never run `git diff`, never open source files. If you need to know something about the codebase, dispatch a scout question to a GLM spinner. You orchestrate; the workers implement.
