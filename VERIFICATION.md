# Verification ledger

This repository makes a public claim. This file says exactly what each part rests on, so you never have to take a claim on trust. Three buckets: what I ran and proved, what I assessed from sources, and what is still open.

## VERIFIED, ran and provable

- **The incident is real and public.** It was filed as a bug report: GitHub issue #64559, https://github.com/anthropics/claude-code/issues/64559 . The cause was a wildcard delete run by a background subagent under inherited shell permission in an automatic run.
- **The two guard hooks work, and you can prove it in one command.** Run `bash hooks/tests/run_tests.sh`. It runs 18 deterministic cases (8 for the interpreter-delete guard, 10 for the edit-surface guard) and checks the exit codes. Expected result: 18 of 18 pass. The guards block on `exit 2` and allow on `exit 0`, the signals the harness honors.
- **The guards block the exact bypass that caused harm.** The interpreter-delete guard blocks deletion smuggled through inline interpreter code (for example `python3 -c "import os; os.remove(...)"`), which slips past a guard that only watches `rm`. This is demonstrated by the test cases.
- **The five-path attack matrix is measured, not asserted.** `bash tests/attack-matrix/run-matrix.sh` feeds concrete attack payloads for each abuse path to each guard and records BLOCKED or ALLOWED from real runs. Results are in `tests/attack-matrix/RESULTS.md`, and CI re-runs and asserts them on every push. It shows what the kit catches (interpreter-delete, the persistence edits, the .env exfil) and, honestly, what it does not (a shell `rm` wildcard, a secret written to a normal file, a poisoned install), each with the layer that does cover it.

## SOURCED, assessed from documentation and public material, not benchmarked by me

- **The free-tools comparison** in `tool-comparison.md` is built from each tool's own README, source, and public issues. Every row links its source. I did not run each tool against each attack, so it describes designed behavior, not measured outcomes.
- **The independent study** of a related permission gap is an arXiv preprint. It is early and not yet peer reviewed. It studied a different automatic mode on one model and did not reproduce this incident. It is corroboration of the pattern, not proof of this specific event.
- **cc-safe-setup adoption figures** (install and hook counts) are self reported by that project. The tool is genuinely real and useful; the marketing numbers are not independently audited here.
- **"Hooks fire even in automatic or bypass mode"** is confirmed by the developer's own test and consistent with the documented blocking behavior, but the vendor docs do not spell out every permission mode in one place. Treat automatic mode as a speed feature, never a safety boundary, and keep a deterministic hook behind it.

## OPEN, not yet done

- **Extending the attack matrix to the full frameworks.** The matrix today measures the guard layer, which is portable and runnable in a script. Driving each full framework (Claude Dynamic Workflows, open-dynamic-workflows, OpenHands, and so on) against the same payloads end to end is the remaining step. Those need their own runtimes and some are unmerged pull requests, so for now they are compared architecturally in `tool-comparison.md`, which stays labeled as sourced.
- **The edit-surface coverage is partial.** `edit-surface-guard.sh` covers a named set of sensitive paths. An agent that writes a script file and then executes it, or uses heavy obfuscation, can still get through. That is a known gap.
- **This is the application layer only.** It does not provide the isolation layer (sandbox, container, non-root, read-only mounts) or the recovery layer (backups). Those belong underneath it and are out of scope for this repo.

## How to challenge any of this

Clone the repo, run the test suite, read the two guard scripts (about twenty lines of logic each), and read the sources linked in `tool-comparison.md`. If something does not hold up, open an issue. The point of working in the open is that you get to check my work.
