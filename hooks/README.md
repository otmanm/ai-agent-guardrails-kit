# Edit Surface + Interpreter Delete Guards (hook "#9")

**For:** Otman · **Date:** 2026-06-06 · Built after the live test where an agent, blocked from `rm`, deleted files via `python3 -c "os.remove(...)"`, bypassing every rm guard and the recycle bin. These two hooks close that door. Tested: 18/18 pass ([tests/run_tests.sh](tests/run_tests.sh)).

## What each one does (plain language)

| Hook | Tool it watches | What it blocks | What it lets through |
|---|---|---|---|
| `interpreter-delete-guard.sh` | Bash | an inline `python/node/deno/bun/perl/ruby/php -c/-e` that calls a delete (`os.remove`, `shutil.rmtree`, `.unlink`, `fs.rm`, `unlink`…) | normal interpreter use, and plain shell (that is the recycle bin's job) |
| `edit-surface-guard.sh` | Write / Edit / MultiEdit / NotebookEdit | writes to **secrets** (`.env`, `*.pem`, `*.key`), **agent config** (`~/.claude/settings*.json`, `~/.claude/hooks/`), **exec on event** (`.git/hooks/`, `.github/workflows/`, `.husky/`), **lockfiles**, `.ssh/` keys | normal source, docs, data |

Both: deterministic, `exit 2` blocks, macOS-safe (`grep -E`, no PCRE), each has a one shot override env var.

## Why this is the right design (this vs that)
- **Guess the danger (classifiers)** try to judge if a command is bad. They miss the quiet/substituted path (today's bypass). 
- **Close the door (these hooks)** instead deny whole *channels* of harm (interpreter deletes, sensitive file edits) regardless of phrasing. Narrower to reason about, harder to talk around.
- **One line decision rule:** block the *door*, not the *sentence*.

## Why a hook and not a memory rule
A hook is enforced by the harness, outside the model, so it fires even in auto/bypass mode. A rule in a config file is advice the model can forget under pressure. (See the layered defense DAG.)

## GAPS (honest: what this does NOT do)
- It does **not** catch deletion via a *script file* the agent writes then runs (`python cleanup.py`). Only inline `-c`/`-e`., then covered by edit-surface-guard (the script write) + sandbox + backup.
- It does **not** gate truncation/overwrite via redirection (`> file`), deliberately, to avoid false positives on normal output.
- Regex matching can be obfuscated (base64/eval) by a determined attacker. This **raises the bar**; it is not absolute. The real backstop is **Layer 2 (sandbox)** + **Layer 3 (backup/git)**.
- It is **Layer 1**. Safety = these hooks + an OS sandbox + 3-2-1 backup, together.

## How to extend
- Add interpreters/primitives to the `grep -E` alternations in `interpreter-delete-guard.sh`.
- Add sensitive paths to the alternation in `edit-surface-guard.sh`.
- Tune the safe scope with the override env vars (`CC_ALLOW_INTERP_DELETE=1`, `CC_ALLOW_SENSITIVE_EDIT=1`) for one-off legitimate actions.

## Install (run in YOUR terminal: an agent cannot wire these in; the classifier blocks self modification of agent config, which is correct)
See the install command in the chat, or:
```bash
python3 hooks/install.py
```
(That backs up `settings.json`, copies both scripts to `~/.claude/hooks/`, and adds the two `PreToolUse` entries idempotently.)

## Verify after install
Re-run today's test: ask Claude to delete the `*copy*` files in `~/sandbox-recycle-test` via Python. It should now be **BLOCKED** by `interpreter-delete-guard` (last time it succeeded).
