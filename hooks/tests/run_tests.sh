#!/bin/bash
# Self-contained tests for the two guards. Builds JSON via jq (no quoting hell),
# pipes to each hook, checks the exit code. Run: bash run_tests.sh
HD="$(cd "$(dirname "$0")/.." && pwd)"
IDG="$HD/interpreter-delete-guard.sh"
ESG="$HD/edit-surface-guard.sh"
pass=0; fail=0
check(){ local desc="$1" exp="$2" hook="$3" json="$4" got
  printf '%s' "$json" | bash "$hook" >/dev/null 2>&1; got=$?
  if [ "$got" = "$exp" ]; then echo "PASS  $desc (exit $got)"; pass=$((pass+1));
  else echo "FAIL  $desc (got $got, want $exp)"; fail=$((fail+1)); fi; }
jb(){ jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
jw(){ jq -nc --arg p "$1" --arg t "${2:-Write}" '{tool_name:$t,tool_input:{file_path:$p}}'; }

echo "== interpreter-delete-guard =="
check "python os.remove blocked"      2 "$IDG" "$(jb 'python3 -c "import os; os.remove(\"/Users/x/a.md\")"')"
check "python shutil.rmtree blocked"  2 "$IDG" "$(jb 'python3 -c "import shutil; shutil.rmtree(\"/Users/x/d\")"')"
check "node fs.unlinkSync blocked"    2 "$IDG" "$(jb 'node -e "require(\"fs\").unlinkSync(\"a\")"')"
check "perl unlink blocked"           2 "$IDG" "$(jb 'perl -e "unlink \"a\""')"
check "python compute allowed"        0 "$IDG" "$(jb 'python3 -c "print(2+2)"')"
check "plain ls allowed"              0 "$IDG" "$(jb 'ls -la')"
check "plain rm allowed (other hook)" 0 "$IDG" "$(jb 'rm foo.txt')"
check "echo mentioning os.remove allowed" 0 "$IDG" "$(jb 'echo see os.remove docs')"

echo "== edit-surface-guard =="
check ".env blocked"            2 "$ESG" "$(jw '/Users/x/proj/.env')"
check ".env.local blocked"      2 "$ESG" "$(jw '/Users/x/proj/.env.local')"
check "claude hooks blocked"    2 "$ESG" "$(jw '/Users/x/.claude/hooks/foo.sh' Edit)"
check "claude settings blocked" 2 "$ESG" "$(jw '/Users/x/.claude/settings.json' Edit)"
check ".git/hooks blocked"      2 "$ESG" "$(jw '/Users/x/proj/.git/hooks/pre-commit')"
check "CI workflow blocked"     2 "$ESG" "$(jw '/Users/x/proj/.github/workflows/ci.yml')"
check "lockfile blocked"        2 "$ESG" "$(jw '/Users/x/proj/package-lock.json')"
check "pem key blocked"         2 "$ESG" "$(jw '/Users/x/proj/server.pem')"
check "normal source allowed"   0 "$ESG" "$(jw '/Users/x/proj/src/app.js')"
check "normal md allowed"       0 "$ESG" "$(jw '/Users/x/proj/README.md')"

echo "----"; echo "PASS=$pass FAIL=$fail"; [ "$fail" = 0 ]
