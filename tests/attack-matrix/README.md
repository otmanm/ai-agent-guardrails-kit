# Attack matrix

A reproducible test that runs concrete attack payloads for the five abuse paths against each guard and records whether the guard blocks or allows the proposed action, **from actual runs**. This is the empirical answer to "what does each guard catch and what does it miss."

## Run it

```bash
bash tests/attack-matrix/run-matrix.sh
```

It prints the matrix, regenerates [`RESULTS.md`](RESULTS.md), and exits non-zero if any combined-kit verdict no longer matches the documented expectation. It runs in CI on every push, so the matrix stays honest over time.

## How it works, and why nothing dangerous happens

The guards are PreToolUse inspectors. They read a **proposed** tool call as JSON on standard input and decide block (exit 2) or allow (exit 0) **without executing the action**. The harness feeds each guard a proposed payload and reads the exit code. No file is deleted, no package is installed, no secret is written. We are measuring the decision, not the consequence.

## What the result shows (and this is the point)

The current measured result is in [`RESULTS.md`](RESULTS.md). The honest summary:

- **The kit blocks** the interpreter-based delete (the side door past a plain `rm` guard), the three persistence edits (`.git/hooks`, agent `settings.json`, CI workflow, including the agent trying to disable its own guard), and writing a secret into a tracked `.env`.
- **The kit does not block** a shell `rm` wildcard (that is cc-safe-setup's job, or a sandbox), a secret written into an ordinary source file (needs a pre-push secret scanner), or a poisoned `npm install` (needs a network-denied sandbox). Each miss names the layer that actually covers it.
- **The controls stay allowed**, which proves the guards do not strangle normal work.

The misses are not failures, they are the boundary of one layer. A command and edit guard is necessary and not sufficient. Real protection stacks this application layer on top of enforced isolation (a sandbox) and backups. The matrix makes that boundary measurable instead of asserted.

## Scope and honesty

This matrix measures the **guard layer** that is portable and runnable in a script. It does not benchmark the full agent frameworks (Claude Dynamic Workflows, open-dynamic-workflows, OpenHands, and so on) end to end, because those need their own runtimes (for example OpenHands needs Docker) and some are unmerged pull requests. Those are compared architecturally, from their own documentation and source, in [`../../tool-comparison.md`](../../tool-comparison.md), and that file is clearly labeled as sourced, not benchmarked. Extending the matrix to drive each full framework against these payloads is the next step beyond this one.
