#!/usr/bin/env python3
"""Install the two guards into ~/.claude. Run in YOUR terminal:
   python3 hooks/install.py
Backs up settings.json, copies the scripts, adds PreToolUse entries idempotently."""
import json, shutil, pathlib, sys

src = pathlib.Path(__file__).resolve().parent
home = pathlib.Path.home()
dst = home / ".claude" / "hooks"
dst.mkdir(parents=True, exist_ok=True)

scripts = ["interpreter-delete-guard.sh", "edit-surface-guard.sh"]
for n in scripts:
    shutil.copy(src / n, dst / n)
    (dst / n).chmod(0o755)
    print("copied", n)

sp = home / ".claude" / "settings.json"
if sp.exists():
    shutil.copy(sp, sp.with_name("settings.json.bak"))
    print("backed up settings.json -> settings.json.bak")
    s = json.loads(sp.read_text())
else:
    s = {}

s.setdefault("hooks", {}).setdefault("PreToolUse", [])

def add(matcher, script):
    cmd = f"~/.claude/hooks/{script}"
    for e in s["hooks"]["PreToolUse"]:
        if e.get("matcher") == matcher:
            for h in e.get("hooks", []):
                if h.get("command") == cmd:
                    print("already wired:", script); return
    s["hooks"]["PreToolUse"].append({"matcher": matcher, "hooks": [{"type": "command", "command": cmd}]})
    print("wired:", matcher, "->", script)

add("Bash", "interpreter-delete-guard.sh")
add("Write|Edit|MultiEdit|NotebookEdit", "edit-surface-guard.sh")

sp.write_text(json.dumps(s, indent=2))
print("\nDone. Restart Claude Code (or /reload) so the new hooks load.")
print("Then re-test: ask Claude to delete ~/sandbox-recycle-test/*copy* via Python -> should be BLOCKED.")
