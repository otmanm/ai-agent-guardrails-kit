#!/bin/bash
# ================================================================
# interpreter-delete-guard.sh — block deletion done THROUGH a runtime
# ================================================================
# WHY THIS EXISTS:
#   When the shell `rm` is blocked, a capable agent substitutes another
#   tool to get the same effect — e.g. `python3 -c "import os; os.remove(...)"`.
#   That bypasses every rm-based guard AND the recycle-bin, so the file is
#   gone with no backup. This was observed live on 2026-06-06.
#   This hook closes that "tool substitution" door.
#
# TRIGGER: PreToolUse      MATCHER: "Bash"      BLOCK: exit 2
# OVERRIDE (one command):  CC_ALLOW_INTERP_DELETE=1
#
# WHAT IT BLOCKS: an inline interpreter invocation (python/node/deno/bun/
#   perl/ruby/php with -c or -e) that ALSO calls a file-deletion primitive
#   (os.remove/unlink/rmdir, shutil.rmtree, pathlib unlink, fs.unlink/rm,
#   File.delete, FileUtils.rm*, bare unlink).
# WHAT IT ALLOWS: normal interpreter use (no deletion), and plain shell
#   commands (those are the job of destructive-guard + the recycle-bin).
# macOS-safe: uses grep -E only (no PCRE / no -P).
# ================================================================

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0
[ "${CC_ALLOW_INTERP_DELETE:-0}" = "1" ] && exit 0

# 1) Is this an INLINE interpreter call? (python -c, node -e, perl -e, ...)
if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(python3?|node|deno|bun|perl|ruby|php)([0-9.]*)?[[:space:]]+-[ce]([[:space:]]|$)'; then
  # 2) Does it invoke a deletion primitive?
  if printf '%s' "$CMD" | grep -qE 'os\.(remove|unlink|rmdir|removedirs)|shutil\.rmtree|\.unlink|\.rmtree|\.rmSync|\.rmdir|fs\.rm|File\.(delete|unlink)|FileUtils\.(rm|remove)|(^|[^[:alnum:]_.])unlink([^[:alnum:]_]|$)'; then
    logfile="${CC_BLOCK_LOG:-$HOME/.claude/blocked-commands.log}"
    mkdir -p "$(dirname "$logfile")" 2>/dev/null
    echo "[$(date -Iseconds)] BLOCKED: interpreter delete | cmd: $CMD" >> "$logfile" 2>/dev/null
    echo "BLOCKED: file deletion through a language runtime (python/node/perl/ruby)." >&2
    echo "" >&2
    echo "Command: $CMD" >&2
    echo "" >&2
    echo "Deleting via code bypasses the rm guard and the recycle-bin, so the file is" >&2
    echo "gone with no backup. Use 'rm' (the recycle-bin will back it up), or move it to" >&2
    echo "the Trash. To override for THIS one command, prefix it with:" >&2
    echo "  CC_ALLOW_INTERP_DELETE=1" >&2
    exit 2
  fi
fi
exit 0
