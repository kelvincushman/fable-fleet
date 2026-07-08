# Fable Fleet

**One cheap AI coordinator that bosses around a team of specialist AIs — each in its own terminal, each doing what it's best at.**

Fable Fleet is a small, file-based framework for running a *multi-model* AI coding fleet on top of [Orca](https://orca.computer) (an agentic dev environment) and [Claude Code](https://claude.com/claude-code). A fast, inexpensive model (**Fable 5**) is the **coordinator** — it plans, delegates, and checks work but never writes code itself. Specialist models do the actual work as headless workers, and every result is checked by an independent reviewer from a *different* AI family.

> Extracted from a real, working setup. Beginner-friendly tutorial: **https://www.kelvinlee.io/blog/fable-fleet-multi-model-ai-orchestration**

> 💡 **The big idea:** Fable 5 is a genuinely clever model — and right now it's cheap and fast to run. So instead of burning that intelligence writing every line itself, we borrow its brain to *run the loop*: it reads the task, works out which model is best for each piece, and routes the work. The cleverness is spent on **decisions, not on grinding out tokens** — a premium brain steering cheap hands. Intelligent model routing, for a fraction of the price.

## 💸 The point: spend fewer tokens, catch more bugs

This whole design exists to **stop burning money on one big model doing everything**. Here's where the savings come from:

- **The "brain" is the cheap model.** Fable 5 does all the planning and delegating — the part that runs constantly — and it's fast and inexpensive. Your pricey model isn't the one idling in the driver's seat.
- **Expensive tokens only where they matter.** Opus 4.8 is reserved for correctness-critical, high-risk slices. *Routine* work never touches it. Bulk work goes to Codex (on a flat-rate subscription), and everything parallelisable or exploratory goes to GLM (cheapest tokens).
- **Subscriptions, not metered API keys.** Claude and Codex run on your existing Max / ChatGPT **subscriptions** — flat cost, not per-token billing. Only GLM and the reviewer use metered keys, and they're the cheap ones.
- **Mechanical checks before paid review.** `scope-check.sh` is plain bash (zero tokens). It catches a worker straying out of scope *before* you spend a single review token on it.
- **State lives in files, so context stays small.** Plans, audits, and reports are markdown on disk — not scrollback. The coordinator reads short summaries instead of re-ingesting huge files, you `/clear` between phases, and nobody re-pays to carry a giant context window around. Summaries over dumps, always.
- **A cheap, fast reviewer.** Cross-family review runs on Qwen-via-Groq — quick and inexpensive — so you can afford to re-run the *full* acceptance-check suite every phase instead of eyeballing it.

Net effect: the meter runs mostly on cheap models and flat-rate subscriptions, the expensive model sips instead of gulps, and a free bash script stops you paying to review broken work.

## The fleet

| Role | Model | Runs as | Job |
|------|-------|---------|-----|
| **Coordinator** | Fable 5 | Claude Code (interactive) | Plans, delegates, gates, transitions. **Never edits code.** |
| **Senior coder** | Opus 4.8 | `claude` headless | Hard, high-blast-radius slices only |
| **Main coder** | Codex 5.5 | `codex exec` | Bulk implementation |
| **Spinners** (1–2) | GLM 5.2 | `pi --provider zai` | Scaffolding, tests, docs, scouting (cheapest tokens) |
| **Verifier** | Qwen (on Groq) | `pi --provider groq` | Independent cross-family review + acceptance checks |

Role contracts live in [`roles/`](roles/) — each tells that model exactly what it may and may not do.

## The loop

1. You brief the coordinator. It writes `feature-research/<task>/plan.md` — every task with an explicit **Files-touched** list and **machine-checkable acceptance criteria** — then opens a gate. **You approve the plan.**
2. It dispatches work: Opus (hard), Codex (bulk), GLM (fan-out), each in its own git worktree so parallel tasks never collide.
3. Workers finish, each writing an `audit-*.md` and signalling done.
4. [`scripts/scope-check.sh`](scripts/scope-check.sh) mechanically verifies each worker only touched files in the plan — before any review token is spent.
5. The coordinator dispatches the **verifier**, which runs every acceptance command verbatim in fresh context and writes `phase-report.md` with a `ship` / `fix first` verdict.
6. `ship` → progress saved, gate to you, fresh worktrees for the next phase. `fix first` → a capped retry ladder (retry → diagnostic panel → human tiebreaker).

Templates for the plan, audit, and phase-report are in [`templates/`](templates/).

## Setup (high level)

1. **Install the tools**: [Orca](https://orca.computer), [Claude Code](https://claude.com/claude-code), the [`codex`](https://github.com/openai/codex) CLI, and [`pi`](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) (a multi-provider agent CLI, used for GLM and Qwen).
2. **Drop this kit into your repo** as `orca/` (roles, templates, scripts).
3. **Add the routing** so each model reads its role automatically — copy the snippets from [`routing/`](routing/) into your repo's `CLAUDE.md` (Claude) and `AGENTS.md` (Codex).
4. **Authenticate the workers.** Claude + Codex run on your *subscriptions* (no API keys) — launch Claude with `env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL claude` so it uses the subscription. GLM needs `ZAI_API_KEY`; Qwen needs `GROQ_API_KEY` (put both in your shell profile so worker terminals inherit them).
5. **Launch the coordinator** (Fable 5) on the main worktree and brief it. That's the only terminal you talk to.

## Running the fleet (every time)

Once it's set up, starting a session is quick — the coordinator only takes charge when you *explicitly* ask it to, so day-to-day dev with the same models is unaffected.

1. **Make sure Orca's runtime is up** (if you run it headless, restart the serve process; on the desktop app it's already running).
2. **Open a terminal on your project's main worktree** in Orca.
3. **Launch the coordinator** on your subscription:
   ```bash
   env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL claude
   ```
   then `/model` → **Fable 5**. Your `ZAI_API_KEY` and `GROQ_API_KEY` live in your shell profile, so worker terminals inherit them automatically — nothing to re-enter.
4. **Brief the coordinator.** Paste something like:
   > Act as the fable-fleet coordinator (`orca/roles/coordinator.md`) and run a fleet phase for: **[your task]**. Write a plan with a Files-touched list and a runnable acceptance test per task, and gate it to me before dispatching anything.
5. **Approve the plan** at the gate, let the workers and verifier run, and **read the verdict**. On `ship`, progress is saved to markdown — `/clear` and start the next phase.

That's it. The magic phrase is step 4: naming the coordinator role is what turns a normal Fable session into the boss.

## Cost routing (don't drift)

- **Opus** = correctness-critical only. Routine work on Opus recreates the token sink this whole thing exists to kill.
- **Codex** = bulk, on your ChatGPT subscription.
- **GLM** = everything parallelisable + all scouting (cheapest tokens).
- **Qwen** = every review, always cross-family, always fresh context.

## License

MIT — see [LICENSE](LICENSE).
