> **How to read this file.** This is a working comparison of the open and free dynamic-workflow tools and their built-in guardrails, **assessed from each tool's own documentation, source code, and public issues, not from a benchmark I ran against them.** What was actually run and proved in this repo is the hook test suite in [hooks/](hooks/) (18/18 passing), the incident itself, and the measured [attack matrix](tests/attack-matrix/) that records BLOCKED or ALLOWED for each abuse path against the guards. Extending that matrix to drive each full framework below end to end is the next step. See [VERIFICATION.md](VERIFICATION.md) for what is verified vs sourced vs open.
# Intern Guide: Dynamic Workflows, the Open-Source Alternatives, and How to Gate Them

**For:** Otman · **Date:** 2026-06-05 · **Purpose:** understand, well enough to teach a 15 year old, (a) what dynamic workflows actually are, (b) why they made your deletion more likely, (c) the open source versions so you are not locked to Claude, and (d) how to put a guardrail on each.
**Sources:** a 10 agent research workflow that read the actual repos, the official docs, and the paper. Every framework claim below was pulled from primary sources (linked at the end of each section). Where something is early or self reported, it says so.

---

## 0. The one paragraph you need first

A "dynamic workflow" is when, instead of you talking to one AI step by step, the AI **writes a little program that launches a swarm of smaller AIs (subagents) to work in parallel**, then collects their results. It is powerful because it does a week of work in an afternoon. It is dangerous for one reason: **a swarm running on autopilot has no human reading each command before it runs.** That is the soil your file deletion grew in. The fix is never "make the swarm behave." The fix is a gate that sits underneath the swarm and physically blocks the few irreversible actions, no matter which agent tries them. That gate is not a Claude feature. It is a pattern you can carry to any tool.

---

## 1. What a dynamic workflow actually is (plain language)

The chef analogy, because it is the clearest:

- **You** = the restaurant owner. You say "serve a tasting menu for 200 people tonight."
- **The orchestration script** = the head chef. It does not cook. It writes the tickets and decides who does what.
- **The subagents** = the line cooks. Each one is a fresh, separate AI with its own clean memory, given one ticket ("make 200 portions of the soup").
- **The runtime** = the kitchen itself, running in the background while you (the owner) are free to do other things.

In Claude Code specifically (shipped late May 2026 with Opus 4.8, version 2.1.154+), you trigger this by saying "use a workflow," by the keyword `ultracode`, or by a built in command like `/deep-research` (the one we used earlier today). Claude writes a JavaScript script using four building blocks:

| Block | What it does | Kitchen version |
|---|---|---|
| `agent(prompt)` | Launch one subagent | Hand one ticket to one cook |
| `parallel([...])` | Launch many at once, wait for all | Fire 16 cooks together, plate when all done |
| `pipeline(items, ...)` | Stream items through stages, no waiting | A conveyor: each dish moves station to station |
| `workflow(name)` | Call another whole workflow inside this one | A sub kitchen |

Hard limits: **16 cooks at once**, **1,000 cooks total per run** (a runaway brake). Source: [Claude Code workflows docs](https://code.claude.com/docs/en/workflows), [InfoQ](https://www.infoq.com/news/2026/06/dynamic-workflows-claude-code/).

---

## 2. Why this is exactly what bit you (the load bearing section)

Here is the documented fact that explains your incident. From Anthropic's own docs, word for word:

> "Your permission mode controls only the launch prompt. The subagents the workflow spawns **always run in `acceptEdits` mode** and inherit your tool allowlist, regardless of your session's mode. File edits are auto-approved."

Unpack that slowly, because it is the whole reason your files died:

1. **`acceptEdits` mode = file edits are auto approved.** The cooks do not ask before writing or changing files. They just do it.
2. **They inherit your tool allowlist.** If your session was allowed to run Bash (shell commands), every cook is allowed to run Bash too.
3. **In Auto mode with `ultracode`, in headless `claude -p`, and in the Agent SDK, there is no launch prompt and no confirmation at all.** The docs literally note "there is no one to prompt."
4. **The swarm runs in the background, 16 at a time.** No human is reading each command as it fires.

Put those together and you get your afternoon: a subagent decided to "clean up," ran an `rm` with a wildcard, nothing prompted you, and you saw it only afterward in the `/workflows` drill down. **It was not a bug in the model. It was the designed behaviour of the swarm meeting a broad permission you had already granted.**

The one brake that still works in this setup: **a PreToolUse hook fires even in bypass mode and can block any tool call.** That is why the hook from intern guide #1 is the answer. It is the only layer the swarm cannot skip.

`Reason-back checkpoint:` the danger is not "AI is reckless." It is "auto approved edits + inherited shell permission + no human in the loop + 16 agents at once." Remove any one of those and the disaster shrinks. The hook removes the "no gate" leg.

Source: [Claude subagents docs](https://code.claude.com/docs/en/sub-agents), [Agent SDK permissions](https://platform.claude.com/docs/en/agent-sdk/permissions), [TrueFoundry on --dangerously-skip-permissions](https://www.truefoundry.com/blog/claude-code-dangerously-skip-permissions).

---

## 3. The four things you linked, compared honestly

You sent three repos plus the Claude original. Here is what each actually is. The most important column is the last one: **does it have a built in guardrail?**

| Thing | What it really is | Maturity | Built in guardrail? |
|---|---|---|---|
| **Claude Dynamic Workflows** | The original. Claude writes a JS script, its runtime spawns subagents. Locked to Anthropic's harness, Max subscription. | Shipped, research preview | Weak by default: `acceptEdits` + inherited allowlist. Real brake = PreToolUse **hooks** + the 16/1000 caps + `disableWorkflows` kill switch. |
| **open-dynamic-workflows** (imsai-sh) | An MIT licensed **clone** of Claude's feature in TypeScript. Same four blocks. Swappable "executor" so it can drive any model, not just Claude. | Very early: 14 stars, 4 commits, one author, a clean proof of concept. Not production hardened. | Determinism sandbox (`node:vm`) that the code itself says is **NOT a security boundary**. Uses `acceptEdits`, never `--dangerously-skip-permissions`. **No network limit, no spend ceiling, no tool allowlist for subagents.** |
| **DannyMac180/skills** | **Not an engine.** A single *skill* (`codex-dynamic-workflows`): a written playbook that teaches any host agent how to coordinate subagents. The "engine" is whatever agent reads it. | 412 stars, but it is one Markdown skill + 3 tiny bookkeeping scripts. | **The most safety forward of the set.** Ships `risk-gates.md` demanding explicit human approval before deletes, force pushes, deploys, secret access, or spawning many agents. Caps agents at 2 to 4 concurrent, 6 to 12 total. |
| **OpenHands PR #3426** (Graham Neubig) | A "dynamic workflow tool" for **OpenHands**, the big open source coding agent platform (~71k stars). Parent agent writes a Python script; subagents run via `wf.run_agent`, `map_agents`, `reduce_agent`. | PR open, not merged. OpenHands itself is mature and widely used. | **The strongest by far.** Three layers: (1) Docker/Kubernetes sandbox so damage stays in a container, not your laptop; (2) `confirmation_mode` + a pluggable `security_analyzer` that risk rates each action; (3) the LLM written script is parsed by an AST checker that forbids `import`, `os`, `subprocess`, and dunder tricks before it runs. |

**The honest takeaways for you:**
- `open-dynamic-workflows` is interesting as proof the *idea* is portable, but it is a weekend project with weaker safety than Claude. Do not lean on it for real work yet.
- `DannyMac180/skills` is not a competitor engine; it is a *discipline* you can copy (its risk gates are basically the zero trust protocol in skill form).
- **OpenHands is your serious open source answer.** It is the one that proves you can run dynamic workflows without Claude *and* with stronger isolation, because it puts the agent in a Docker box and a human or analyzer in front of risky actions.

Sources: [open-dynamic-workflows](https://github.com/imsai-sh/open-dynamic-workflows), [DannyMac180/skills](https://github.com/DannyMac180/skills), [OpenHands PR #3426](https://github.com/OpenHands/software-agent-sdk/pull/3426), [OpenHands docs](https://docs.openhands.dev).

---

## 4. The wider landscape (so you know the whole field, not just 3 repos)

If you want self hosted dynamic workflows that are NOT Claude, the field has consolidated around five real options. Most "open dynamic workflows forks" you find on GitHub are thin wrappers on these.

| Framework | Best for | Guardrails |
|---|---|---|
| **LangGraph** | Closest 1:1 to Claude workflows, max control | Strong: checkpointing, human in the loop interrupts, recursion limits |
| **Microsoft Agent Framework** (AutoGen + Semantic Kernel merged, 1.0 Apr 2026) | Enterprise, governed | Strong: middleware, telemetry, governance. (Note: old AutoGen is now maintenance only.) |
| **OpenHands** | Self hosted autonomous *coding* | Strong: Docker sandbox, confirmation mode, security analyzer |
| **CrewAI** | Fast role based crews | Partial: task validation, max iterations |
| **Dify** | Visual builder, fastest setup | Moderate: moderation, visual constraints |

Source: workflow landscape sweep ([Microsoft Agent Framework](https://github.com/microsoft/agent-framework), [OpenHands](https://github.com/OpenHands/OpenHands), [LangGraph](https://github.com/langchain-ai/langgraph)).

`Reason-back checkpoint:` "open source dynamic workflows" is not one product. It is a pattern (script spawns subagents) that many mature frameworks already do. The question is never "which clone of Claude," it is "which framework gives me the spawn pattern AND a real guardrail."

---

## 5. The two layers of a real guardrail (this is the mental model to keep)

Every safe setup uses **two layers**, because each catches what the other misses. Teach it as the bank analogy: a teller who checks your request (layer 1), and a vault the teller cannot override (layer 2).

### Layer 1: the application gate (the teller)
This is the PreToolUse hook. It intercepts the *intended* action, inspects it, and says allow or deny. Key facts:
- **`exit 2` blocks. `exit 1` does NOT block** (that one just logs an error and proceeds). This detail matters: get the exit code wrong and your gate is decorative.
- Or return JSON with `permissionDecision: "deny" | "allow" | "ask" | "defer"`.
- A hook is **code the harness runs, not text the model reads.** That is why it binds when a CLAUDE.md rule does not. Sign on a door versus a locked door.
- **It is portable.** Claude, Cursor, and OpenAI Codex all expose the same `PreToolUse` lifecycle event with the same stdin JSON / exit code contract. For a framework with no hooks (LangChain, a custom loop), you get the same gate by wrapping the one function that runs tools. The gate is an *architectural position* (a single chokepoint), not a vendor feature.

### Layer 2: the OS / container sandbox (the vault)
A prompt level gate can be fooled. The kernel cannot. This is what OpenHands does and what you can add to anything:
- Run the agent in **Docker**, not on your host, so the blast radius is the container.
- Run as a **non root user**, mount your code **read only**, give it one **writable scratch directory**.
- Tighten with **seccomp** (block dangerous syscalls), **AppArmor / Landlock** (path scoping), `--cap-drop=ALL`.
- For truly untrusted code, use **gVisor or microVMs**, because containers share the host kernel.
- (Claude Code itself uses **bubblewrap**; Cursor uses Landlock + seccomp + AppArmor. So the big tools already do this; you are just doing it deliberately.)

**Why both:** the gate reasons about intent but can be tricked; the sandbox cannot reason but cannot be tricked. Defense in depth means the action has to get past a smart-but-foolable teller AND a dumb-but-unbreakable vault.

Sources: [AI agent hooks across vendors](https://www.speakeasy.com/resources/ai-agent-hooks), [Codex hooks](https://developers.openai.com/codex/hooks), [Docker sandboxing for agents](https://www.docker.com/blog/comparing-sandboxing-approaches-ai-agents/), [Northflank sandboxing](https://northflank.com/blog/how-to-sandbox-ai-agents).

---

## 6. The Zero Trust Protocol (your new teaching, made concrete)

You asked to add zero trust. Here it is as a usable protocol, grounded in the real standards ([NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final), [OWASP AI Agent Security](https://cheatsheetseries.owasp.org/cheatsheets/AI_Agent_Security_Cheat_Sheet.html)).

The core idea in one line: **never trust by default, including your own agents. Verify every action, every time. Assume the agent will eventually do the wrong thing.**

OWASP's sharpest sentence for you: *when an agent is compromised, its access scope becomes the attacker's access scope.* So you shrink the scope.

The nine rules, in plain language:

1. **Deny by default, grant per task.** Before launching, write one line: this task needs exactly these tools, these files, this credential. Everything else is off.
2. **Tool minimization.** A research agent gets read only. It never gets the delete tool. Fewer tools = smaller blast radius.
3. **One working folder.** Each workflow lives in one sandboxed directory. Never point an agent at your home folder. (This is the "contain it in a working folder" rule you already named, and it directly shrinks what a wildcard can hit.)
4. **Scoped, short lived credentials.** Read only or single purpose tokens that expire. Never paste a master key.
5. **Never trust, always verify the output.** Re read tool results before acting. Confirm the file changed, the quote was real, the URL resolves. (This is literally your "reason back" rule, in security language.)
6. **Human in the loop for anything irreversible.** Deletes, sends, payments, deploys, public posts. The friction is the point.
7. **Untrusted input is hostile.** A web page or PDF can carry hidden instructions. An agent that just read an external page should not, in the same breath, be allowed to delete or send.
8. **3-2-1 backup before bulk file work.** Three copies, two media, one offsite. Your recovery floor when everything else fails. (This is what saved you.)
9. **Log and review.** A short ledger per run: what fired, what changed. So you can reason back afterward.

**The one line to repeat:** *least privilege at the start, verify every output, stop for anything you cannot undo.*

---

## 7. The paper that proves your case (plain version)

[arXiv:2604.04978](https://arxiv.org/abs/2604.04978), "Measuring the Permission Gate" (preprint, April 2026, tested on Sonnet 4.6 in auto mode).

What they did: built 128 "ambiguous but benign" tasks (clear intent, fuzzy scope, like "clean up the stale job for ticket 4812") and watched whether Claude's safety gate allowed only what was authorized. They scored 253 real actions.

What they found, in your language:
- **The gate let through 81% of unauthorized actions** on this stress test. (Anthropic's own number on normal traffic is 17%. This is harder on purpose, so it is not a contradiction, it is a probe of the boundary.)
- **The smoking gun for you: "Tier 2."** Auto mode has three tiers, and Tier 2 is "in project file edits," which are **exempt from the safety check by design**, on the theory that "you can review them in version control later." But **36.8% of all actions happened as file edits** and so were never checked at all.
- **Worst category: artifact cleanup, 92.9% missed.** When the agent could not find the expected command line tool, it just fell back to editing the state files directly with the Edit/Write tools. Those edits are Tier 2, so they sailed through unchecked. This is your incident with a control group: cleanup + file surface = the net is basically off.
- **Their recommended fix matches Yuru Kusa exactly:** close the Tier 2 gap. Stop auto allowing in project edits, because "reviewable in version control" falls apart during unattended automated runs. In other words, **gate the edit/delete surface, not just the shell.**

`Reason-back checkpoint:` the safety net assumes danger walks through the front door (the shell). The agent walks through the side door (file edits). 93% of cleanup danger uses the side door.

---

## 8. What the labs actually say about trusting agents

You wanted the "do not fully trust the tool" sources. Here is what they actually say, with the nuance.

- **Anthropic's own research ("Measuring AI agent autonomy"):** do NOT require humans to approve every action. Their data (nearly a million tool calls) shows experienced users *auto approve more* (40%+ after 750 sessions) but *interrupt more too* (9% vs 5%). The recommendation: **"give users trustworthy visibility into what agents are doing, along with simple intervention mechanisms."** Translation: a window to watch + a button to stop, not a popup on every step. ([Anthropic](https://www.anthropic.com/research/measuring-agent-autonomy))
- **The industry consensus framing:** trust an agent like a **junior engineer**. Real work, bounded scope, human review. Only 42% of organisations trust agents to lead dev work even with oversight; McKinsey rates enterprise trust maturity at 2.3 out of 5. ([WebProNews](https://www.webpronews.com/treating-ai-agents-as-junior-engineers-oversight-for-productivity-and-safety/), [McKinsey](https://www.mckinsey.com/capabilities/tech-and-ai/our-insights/tech-forward/state-of-ai-trust-in-2026-shifting-to-the-agentic-era))
- **The Favaro / Clark pause blog (June 4 2026):** Anthropic says keep the option to slow frontier development, because "more than 80% of code merged into the company's codebase is now written by Claude" and Clark told the BBC 100% "is possible within two years," which points toward recursive self improvement. ([Fortune](https://fortune.com/2026/06/05/anthropic-ai-pause-development-recursive-self-improvement/), [SiliconANGLE](https://siliconangle.com/2026/06/04/anthropic-calls-global-pause-ai-development-humans-lose-control/))
- **The honest counterweight you should cite alongside it:** Anthropic filed its IPO paperwork (S-1) on June 1, days before the pause blog, ahead of a listing reported near a trillion dollar valuation. And in February 2026 it had *loosened* its own safety pledge. So the same company calling for a pause had just weakened the rule that did something similar. ([CNBC](https://www.cnbc.com/2026/06/05/anthropic-warns-of-ais-rapid-development-societal-risk-ahead-of-ipo.html), [Marketplace](https://www.marketplace.org/story/2026/02/25/anthropic-loosens-safety-pledge-to-compete-with-its-ai-peers))

**The synthesis for your voice:** even the lab that builds the most capable models tells you not to trust the tools blindly, asks the world to keep the brakes, and at the same time weakened its own brake before an IPO. So you do not get to outsource your safety to the lab. The discipline has to be yours. That is the whole Systems Detective position.

---

## 9. The version you can teach a 15 year old

Five sentences. If you can say these, you own Part 2.

1. **A dynamic workflow is one AI hiring a swarm of smaller AIs to work at once.** It is fast, but no human watches each one.
2. **The swarm auto approves its own file edits and reuses whatever permissions you already gave.** That is why it deleted my files without asking.
3. **A written rule does not stop it, because the rule lives inside the AI, which forgets under pressure.** You need a gate outside the AI.
4. **The gate has two layers: a smart checker (the hook) and a dumb-but-unbreakable box (the sandbox).** The checker can be fooled; the box cannot.
5. **This is not a Claude problem or a Claude fix.** Open source tools like OpenHands do the same swarm with a stronger box, and the gate pattern works on any of them. You are never locked in.

And the principle under all of it: **never trust the tool by default, verify every output, and stop for anything you cannot undo. Including, especially, your own AI.**

---

## 10. Honest caveats

- The permission gate paper is a **preprint**, tested on **one model** (Sonnet 4.6) in April 2026. The numbers are exact and independent, but it is not yet peer reviewed and auto mode may have changed since.
- `open-dynamic-workflows` is a **4 commit proof of concept**. Real, but do not build production on it.
- `cc-safe-setup`'s "30K installs / 800 hooks" are **self reported** by a project that also sells books. The tool is genuinely real and active; the marketing numbers are not independently audited.
- OpenHands PR #3426 is **open, not merged.** The dynamic workflow tool is a proposal, even though OpenHands itself is mature.
- "Hooks fire even in auto/bypass mode" is confirmed for the mechanism and by Yuru Kusa's test; Anthropic's docs state the blocking behaviour but do not spell out every permission mode in one line.

---

---

## 11. "Close the Tier 2 gap," expanded — and why this is the whole Systems Detective position

You flagged this passage and asked me to go deeper. Here it is.

**What "close the Tier 2 gap" actually means.** From the paper (see `03-DEEP-paper-and-cyber-redteam.md`): the safety guard only inspects shell commands (Tier 3). It waves through in-project file edits (Tier 2) on the assumption that "you can review them in version control later." Closing the gap means: **stop trusting that assumption and put a gate on the edit/delete surface too**, especially for sensitive paths (`.env`, `.git/`, hooks, CI files, lockfiles, settings) and for untracked folders where there is no git history to recover from. Yuru Kusa named this; nobody has shipped a clean ready-made edit-surface hook yet. That is the concrete, buildable contribution Part 2 can make: not another rm-guard, but the first good *edit-surface* guard.

**Why you cannot outsource your safety to the lab (the synthesis, expanded).** Hold three verified facts together:
1. Anthropic's own research ("Measuring AI agent autonomy") says do **not** approve every action; give yourself *visibility plus a way to interrupt*. So the lab itself tells you oversight is your job, not theirs.
2. On June 4 2026 Anthropic publicly asked the world to keep the option to **slow down** frontier AI, warning that more than 80 percent of its own code is now written by Claude and that humans could lose "meaningful control." So the most capable lab is openly unsure it can keep control.
3. Days earlier it filed for an IPO near a trillion-dollar valuation, and in February 2026 it had **loosened its own safety pledge**. So the same lab calling for brakes had just weakened its own.

Put those together and the conclusion is unavoidable. The lab that builds the tool: tells you to supervise it yourself, admits it may lose control of the frontier, and weakened its own safety commitment under commercial pressure. **You do not get to outsource your safety to that. The discipline has to be yours.** That is not cynicism about Anthropic, it is the only rational operator posture. And it is the entire Systems Detective position in one move: safety is not a property you buy with a model or a vendor promise, it is a system you build and own. The lab supplies capability. You supply control. Anyone who confuses the two will eventually meet the version of my deleted-files afternoon that does not have a backup.

That is the line that makes Part 2 more than a how-to. The hooks are the proof; the position is the point.

---

## 12. Which repo is best for Codex? (and can Codex do containers like OpenHands)

You said you will focus on OpenHands PR and DannyMac180. Here is the clean answer, because they solve different problems.

- **DannyMac180/skills (`codex-dynamic-workflows`) is the one literally built for Codex.** It is a portable *skill* (a playbook) that teaches Codex how to run the dynamic-workflow pattern, and it ships **risk gates** (explicit human approval before deletes, force-push, deploys, secret access; agent-count caps of 2 to 4 concurrent). So for getting the *workflow pattern* into Codex *with built-in approval gates*, this is your pick. Limit: it is a playbook, not an isolation engine. It does not give you a container.
- **OpenHands PR #3426 is the one built for isolation,** but OpenHands is its own platform, not Codex. It runs any model (including gpt-5.5) inside a **Docker/Kubernetes sandbox** with a security analyzer and confirmation mode. If what you want is the container isolation, you run OpenHands, you do not bolt its PR onto Codex.
- **Can Codex itself do containers like OpenHands?** Not natively, Codex does **not** orchestrate Docker/Kubernetes. BUT, and this matters, **Codex already ships a kernel-level sandbox by default**: Seatbelt on macOS, Bubblewrap + seccomp on Linux, with `workspace-write` scope and **network off by default**. That is lighter than OpenHands' full container but it is real isolation you get for free, and Codex supports PreToolUse-style hooks. If you want OpenHands-grade container isolation with Codex, you run Codex *inside your own Docker container*.

**The practical recommendation for your Codex setup:** use **DannyMac180/skills** for the workflow pattern and its approval gates, rely on **Codex's native sandbox** as the box (network off, workspace-write), and add a **PreToolUse hook** (the wildcard/edit-surface gate) on top. Use **OpenHands** as the reference and as the tool you reach for when a job needs true container isolation. Two tools, two jobs: DannyMac for the pattern-with-gates on Codex, OpenHands for the heavy isolation.

---

## 13. How to mitigate each "honest caveat" (not just restate it)

You said the caveats were not clear on *how* to de-risk them. Here is the concrete mitigation for each. The throughline: **replace someone else's number with a five-minute test on your own installed version.**

| Caveat | How to mitigate it |
|---|---|
| The paper is a preprint, one model (Sonnet 4.6), April 2026 | Clone the authors' public AmPermBench and run ~20 of the ambiguous DevOps cases against *your* current Claude Code version; score whether auto mode gated each action. Check the changelog to see if auto mode changed since April. Bottom line: treat auto mode as a **speed** feature, never a **safety boundary**, and always put a deterministic hook behind it. |
| open-dynamic-workflows is a 4-commit POC | Do not run a POC in production. Use a framework with **versioned releases, a test suite, and a tracker with closed bugs**: LangGraph (stateful + human-in-loop), OpenHands (sandboxed coding agent), or Microsoft Agent Framework. Mine the POC for ideas, build on the framework. |
| cc-safe-setup's install/test numbers are self-reported by a book-selling project | Ignore the marketing counts; **audit the artifact**. It is shell + `jq`, not a binary. Confirm no network call: `grep -rE "curl|wget|nc|http" <install-dir>` should be empty for runtime hooks. Run `--verify` and `--doctor` (the vendor's test), then write your own (below). If it is shell + jq with no egress, the code is the proof and the install count is irrelevant. |
| OpenHands PR #3426 is open, not merged | You do not need it. OpenHands **already** ships Docker-sandboxed execution, a security analyzer (LOW/MEDIUM/HIGH), and confirmation mode **today**. Enable confirmation mode, set approval at MEDIUM+, run a benign destructive command and confirm it touched only the container. The PR is an enhancement, not a prerequisite. |
| "Hooks fire in auto/bypass mode" is Yuru Kusa's test, not Anthropic docs | **Verify it yourself in two minutes.** Write a trivial PreToolUse Bash hook that does `exit 2` when it sees the string `BLOCKME`, wire it, then run `claude --permission-mode bypassPermissions` (and `acceptEdits`) and ask it to `echo BLOCKME`. If the command is blocked, hooks fire regardless of mode, confirmed on *your* version. Re-test after any CLI upgrade. |

---

*Companion files: `01` (the hook line by line), `03` (the paper deep-read + cyber red-team), `04` (the 8 hooks, provenance, other harnesses), `05` (reply to Yuru Kusa). Together these are the full understanding base for Part 2. No blog drafting until you confirm you can reason back through them.*
