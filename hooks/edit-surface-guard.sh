#!/bin/bash
# ================================================================
# edit-surface-guard.sh — gate the Tier-2 "side door" (file edits)
# ================================================================
# WHY THIS EXISTS:
#   The research paper (arXiv:2604.04978) showed the safety classifier does
#   NOT inspect in-project file edits (Tier 2), so an agent can change
#   secrets, CI, git hooks, or its OWN config by editing files directly.
#   Shell hooks never see this. This hook watches the Edit/Write tools and
#   blocks writes to high-blast-radius files.
#
# TRIGGER: PreToolUse   MATCHER: "Write|Edit|MultiEdit|NotebookEdit"
# BLOCK: exit 2         OVERRIDE (one action): CC_ALLOW_SENSITIVE_EDIT=1
#
# WHAT IT BLOCKS (writes to):
#   - secrets:        .env / .env.* , *.pem *.key *.p12 *.pfx *.keystore *.crt
#   - agent config:   ~/.claude/settings*.json , ~/.claude/hooks/*  (self-mod)
#   - exec-on-event:  .git/hooks/* , .github/workflows/* (CI), .husky/*
#   - dependency locks: package-lock.json, yarn.lock, pnpm-lock.yaml,
#                       poetry.lock, Cargo.lock, Gemfile.lock
#   - registries/keys: .npmrc, .pypirc, anything under .ssh/, id_rsa, id_ed25519
# WHAT IT ALLOWS: normal source / docs / data files.
# macOS-safe: grep -E only.
# ================================================================

INPUT=$(cat)
FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.notebook_path // empty' 2>/dev/null)
[ -z "$FP" ] && exit 0
[ "${CC_ALLOW_SENSITIVE_EDIT:-0}" = "1" ] && exit 0

if printf '%s' "$FP" | grep -qE '(^|/)\.env($|\.|/)|\.(pem|key|p12|pfx|keystore|crt)$|(^|/)\.git/hooks/|(^|/)\.github/workflows/|(^|/)\.husky/|/\.claude/(settings[^/]*\.json|hooks/)|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|Cargo\.lock|Gemfile\.lock)$|(^|/)\.npmrc$|(^|/)\.pypirc$|(^|/)\.ssh/|id_rsa|id_ed25519'; then
  logfile="${CC_BLOCK_LOG:-$HOME/.claude/blocked-commands.log}"
  mkdir -p "$(dirname "$logfile")" 2>/dev/null
  echo "[$(date -Iseconds)] BLOCKED: sensitive edit | path: $FP" >> "$logfile" 2>/dev/null
  echo "BLOCKED: edit to a sensitive file." >&2
  echo "" >&2
  echo "Path: $FP" >&2
  echo "" >&2
  echo "Editing secrets, agent config, git hooks, CI files, or lockfiles is the" >&2
  echo "high-blast-radius side door (the Tier-2 gap). If you truly intend this," >&2
  echo "make the change yourself, or override for ONE action with:" >&2
  echo "  CC_ALLOW_SENSITIVE_EDIT=1" >&2
  exit 2
fi
exit 0
