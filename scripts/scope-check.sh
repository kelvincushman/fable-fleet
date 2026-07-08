#!/usr/bin/env bash
# scope-check.sh — mechanical drift detection. No LLM, no trust.
#
# Usage:
#   scope-check.sh --snapshot
#       Print the current changed-files set (staged + unstaged vs HEAD +
#       untracked, gitignored excluded), one path per line. Run this at
#       PHASE START, BEFORE dispatching workers, and save it as the baseline.
#       Required when workers run in the MAIN (dirty) worktree so pre-existing
#       local changes aren't misread as scope violations. In a fresh worktree
#       the snapshot is empty and the baseline is optional.
#
#   scope-check.sh [--baseline <snapshot.txt>] <allowed-files.txt> [audit.md]
#       Run INSIDE the worker's worktree after it reports done, BEFORE review.
#       With --baseline, files listed in <snapshot.txt> are subtracted first,
#       so only changes the worker actually introduced are checked.
#
#   <allowed-files.txt>  one path per line — the plan's "Files touched" list.
#                        Fable emits this from the plan (no code reading).
#   [audit.md]           optional — the worker's audit. If given, every
#                        worker-changed file must be named in it.
#
# Exit 0 = clean. Exit 1 = drift detected (details on stdout).
# On exit 1, the coordinator treats it like a failed verification:
# feed the output to the retry ladder as a blocking issue. Do NOT
# dispatch the verifier until scope-check passes — don't spend review tokens
# on a diff that's already known-bad.

set -euo pipefail

# Changed = staged + unstaged (vs HEAD) + untracked (gitignored excluded).
changed_set() {
  { git diff --name-only HEAD 2>/dev/null; \
    git ls-files --others --exclude-standard; } | sort -u
}

# --- snapshot mode ---------------------------------------------------------
if [ "${1:-}" = "--snapshot" ]; then
  changed_set
  exit 0
fi

# --- arg parsing (flags then positionals; positional calls stay compatible)-
BASELINE_FILE=""
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline)   BASELINE_FILE="${2:?--baseline requires a file argument}"; shift 2 ;;
    --baseline=*) BASELINE_FILE="${1#*=}"; shift ;;
    *)            POSITIONAL+=("$1"); shift ;;
  esac
done
if [ ${#POSITIONAL[@]} -gt 0 ]; then set -- "${POSITIONAL[@]}"; else set --; fi

ALLOWED_FILE="${1:?usage: scope-check.sh [--baseline <snapshot>] <allowed-files.txt> [audit.md]}"
AUDIT_FILE="${2:-}"

if [ -n "$BASELINE_FILE" ] && [ ! -f "$BASELINE_FILE" ]; then
  echo "BASELINE MISSING: $BASELINE_FILE does not exist — capture it at phase start with 'scope-check.sh --snapshot'"
  exit 1
fi

FAIL=0

# Actually-changed files, minus anything already present at phase start.
CHANGED=$(changed_set)
if [ -n "$BASELINE_FILE" ] && [ -s "$BASELINE_FILE" ]; then
  CHANGED=$(printf '%s\n' "$CHANGED" | grep -vxF -f "$BASELINE_FILE" || true)
fi

# --- Check 1: scope --------------------------------------------------------
# Every changed file must be in the allowed list.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # audit/report files under feature-research/ and orca/ are always allowed
  case "$f" in feature-research/*|orca/*) continue ;; esac
  if ! grep -Fxq "$f" "$ALLOWED_FILE"; then
    echo "SCOPE VIOLATION: $f changed but not in plan's Files-touched list"
    FAIL=1
  fi
done <<< "$CHANGED"

# --- Check 2: audit honesty (optional) -------------------------------------
# Every changed file must be named somewhere in the audit.
if [ -n "$AUDIT_FILE" ]; then
  if [ ! -f "$AUDIT_FILE" ]; then
    echo "AUDIT MISSING: $AUDIT_FILE does not exist — blocking by itself"
    FAIL=1
  else
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      case "$f" in feature-research/*|orca/*) continue ;; esac
      if ! grep -Fq "$f" "$AUDIT_FILE"; then
        echo "AUDIT OMISSION: $f was changed but never mentioned in audit"
        FAIL=1
      fi
    done <<< "$CHANGED"
  fi
fi

if [ "$FAIL" -eq 0 ]; then
  echo "scope-check: CLEAN ($(echo "$CHANGED" | grep -cv '^$' || true) files in scope, baseline-adjusted)"
fi
exit "$FAIL"
