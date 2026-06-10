# AI Agent Guardrails Kit

[![tests](https://github.com/otmanm/ai-agent-guardrails-kit/actions/workflows/tests.yml/badge.svg)](https://github.com/otmanm/ai-agent-guardrails-kit/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A background AI agent deleted my files. Not a bug. The designed behavior of a powerful tool meeting a permission I had already granted. I wrote it up in public, a developer in Japan showed me the missing layer, and this repository is the honest, reproducible backing for that story.

Read the reader facing article first: **https://systemsdetective.com/blog/the-lab-shipped-the-gap/**

The original public bug report: **https://github.com/anthropics/claude-code/issues/64559**

## What I ran versus what I assessed

This matters, so it is the first thing you see.

- **Ran and proved (reproducible):** the incident itself; the two guard hooks in [`hooks/`](hooks/), which pass an 18 case test suite; and the [attack matrix](tests/attack-matrix/), which runs concrete payloads for all five abuse paths against the guards and records what is blocked and what is not, from real runs. Both run in one command and in CI.
- **Assessed from sources (not benchmarked):** the comparison of the other free and open tools in [`tool-comparison.md`](tool-comparison.md). It is built from each tool's own documentation, source, and public issues, not from a benchmark I ran against them.
- **Planned next:** a reproducible cross-tool attack harness that records, per tool, which of the five abuse paths it catches and which it misses. Until that ships, the comparison is clearly labeled as sourced.

The full ledger is in [`VERIFICATION.md`](VERIFICATION.md). No claim here asks you to trust me. Every one points to what it rests on.

## What is inside

| File | What it is |
|---|---|
| [`incident.md`](incident.md) | The corrected, public account of the file deletion incident and the layered fix. |
| [`abuse-paths.md`](abuse-paths.md) | The five ways an agent like this can be abused, with real precedents (red-team analysis). |
| [`tool-comparison.md`](tool-comparison.md) | A sourced comparison of the open and free dynamic-workflow tools and their built-in guardrails. |
| [`hooks/`](hooks/) | Two working PreToolUse guard hooks, an installer, and the test suite. The part that was actually run. |
| [`tests/attack-matrix/`](tests/attack-matrix/) | A reproducible matrix that runs each abuse path against each guard and records BLOCKED or ALLOWED. The measured "what it catches and what it misses." |
| [`VERIFICATION.md`](VERIFICATION.md) | The confidence ledger: verified vs sourced vs open. |

## Quickstart

The guards are deterministic shell hooks that the harness runs before a tool call. They block the dangerous shape of an action and let normal work through.

```bash
# 1. Run the test suite (no install needed, proves the guards work)
bash hooks/tests/run_tests.sh        # expect 18/18 pass

# 2. Install the guards into your Claude Code settings (idempotent, backs up first)
python3 hooks/install.py
```

`interpreter-delete-guard.sh` blocks deletion smuggled through inline interpreter code (Python, Node, Perl, Ruby, PHP), the path that slips past a plain `rm` guard. `edit-surface-guard.sh` blocks edits to sensitive files (`.env`, `.git/hooks`, CI config, agent settings, lockfiles), the edit surface that a shell-only guard never sees. Both log blocked actions and support a one-shot override for legitimate cases. See [`hooks/README.md`](hooks/README.md).

## Honest limits

A command guard is one layer, not a wall. It can be slipped by a sufficiently obfuscated command, and it does less for an agent that quietly changes file contents rather than deleting them. Real protection combines this checkpoint with enforced isolation (a sandbox or container with least privilege) and backups underneath. This repo is the application layer, deliberately, and it says so everywhere.

## Credit

Yuru Kusa, and his project [cc-safe-setup](https://github.com/yurukusa/cc-safe-setup). A stranger who got the design right, and gave it away.

## License

MIT, see [`LICENSE`](LICENSE).

If you run AI agents on work that matters and want this boundary drawn properly, that is the kind of thing I do: https://systemsdetective.com/#conversation
