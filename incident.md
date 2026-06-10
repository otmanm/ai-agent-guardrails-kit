# The incident: a background AI agent deleted my files

This is the corrected, public account of the incident this repository is built around. The reader facing article is live at https://systemsdetective.com/blog/the-lab-shipped-the-gap/ . The original public bug report is GitHub issue #64559: https://github.com/anthropics/claude-code/issues/64559 . What each claim rests on is recorded in [VERIFICATION.md](VERIFICATION.md).

## What a dynamic workflow is

When most people use AI, they work one step at a time. You ask, it answers, you read it, you ask the next thing. You see every move. That gives you more chances to notice a bad move before it lands.

A dynamic workflow is a different animal. You give the AI one big instruction, like "research this and build me the report." Instead of doing it step by step in front of you, the AI writes its own little program, and that program spins up a swarm of smaller AIs, called subagents, that go off and work on their own, in the background, many at once. Each one can read files and run commands without checking in.

Here is what that program looks like when the AI writes it. You do not type this. The AI does:

```
const results = await parallel([
  agent("audit the authentication code"),
  agent("audit the payment code"),
  agent("clean up the temporary files"),   // the one that deleted mine
])
```

Three subagents, fired at the same time. Each one is a separate AI with its own memory. The tool can run up to sixteen at once and up to a thousand across a single job. Those are limits, not a normal run.

## The exact gap

Now the part that explains the disaster, and it comes straight from the toolmaker's own documentation. Those subagents run in what is called accept edits mode. In plain words: their file changes are approved automatically, and they inherit the tool permissions of the main session. My session had broad shell access. That meant the background helpers could use it without another prompt. No human was reading each command as it fired. One subagent tried to clean up, ran a delete with a wildcard, and my files were gone before I knew a command had run. It was the designed behavior of a swarm meeting a permission I had already granted.

This is not only a Claude problem. Other tools can coordinate several agents too. Some add approval rules. Some add stronger isolation. You can do this without Claude. But the power travels with the pattern, and so does the danger. Swapping the brand does not remove the risk. You still need guardrails.

## What happened, precisely

One of those background helpers tried to tidy up. It ran a delete command that was meant to remove only its own temporary scratch files. The command used a wildcard, a pattern like "delete everything that matches this." A wildcard can be previewed before anything is deleted. That did not happen. Several of my real files shared a piece of the pattern. They were swept up and deleted with the scratch files.

The AI was not evil. It had enough access to take an action I had not requested, and nothing forced it to inspect the full target list first. That distinction is the whole story.

## The fair criticism

The tool that did this is a frontier product from a major AI lab. The lab shipped permission prompts, allowlists, hooks, limits, and a kill switch. But the protection this destructive path needed was not active by default at the boundary that mattered. The capability was on. The matching guard was not.

My part matters too. I had granted broad shell access for ordinary work. The background helpers inherited it. I gave too much. The product let that access spread.

An independent university team has documented a related gap in a different automatic mode. Its study supports the wider lesson, but it did not reproduce my incident. It is corroboration of the pattern, not a recording of my afternoon. See [VERIFICATION.md](VERIFICATION.md).

## Why the magic button fixes do not work

When this happens, the internet hands you a tempting answer: just turn off the dangerous command. Add one rule that blocks all deletes. One click, done, safe forever.

If you block every delete, you also block the hundred safe, useful deletes you need every day, clearing a build folder, removing junk files. So the rule gets in your way constantly. And what do humans do with a rule that gets in the way constantly. They switch it off. A week later you are unprotected again, except now you think you are safe, which is worse.

Real safety is never one switch. It is a few simple layers that each catch what the others miss, and that do not punish you for working normally.

## How the fix arrived

I did not hide the failure. I wrote it up in public, as a bug report, and explained exactly what went wrong. A developer in Japan, Yuru Kusa, read it and replied. Not the lab. He explained the real cause better than I could: the command had never listed and checked the files matched by the wildcard before deleting them. He pointed me at a guardrail that catches this dangerous command shape. He maintains a small open project, cc-safe-setup, and he gave it away free.

His checkpoint is one useful layer at the application level. It is real and it helped. It is not the complete fix. A checkpoint that matches command patterns can be slipped by an obfuscated command, can miss damage done through file edits rather than the shell, and can be turned off by an agent that is allowed to edit the guard itself. One good layer is not a safety system. That is why this repo ships layered guards plus an honest list of what they do not cover.

## The fix that actually worked

Four habits and one mindset. Each one is simple. Together they mean a bad command is an annoyance, not a disaster.

1. Back up before you let the AI run free. Keep more than one copy, on more than one kind of storage, with one copy somewhere else. A deleted file with a backup is a shrug, not a loss.
2. Give the AI one room, not the whole house. Keep the job inside a single working folder, and enforce that boundary with permissions or a sandbox. A folder is not a wall unless the system makes it one.
3. Put a guard at the door. A checkpoint that reads a command before it runs, blocks the dangerous shape, and lets normal safe deletes through. This is the layer in [hooks/](hooks/).
4. Assume the tool can be wrong. Treat every powerful action as something that can misfire, and build the small safety net before, not after.
5. Be able to reason back. If you cannot explain what your AI just did, you are not in control of it, you are hoping.

## The honest edges

I will not sell certainty I do not have. The guard here blocks dangerous command patterns well. It can miss an obfuscated command. It does less for a sneakier risk, where an AI quietly changes the contents of files rather than deleting them, which is why this repo also ships an edit surface guard, and why strong protection still needs enforced isolation and backups underneath. The university study is early. The lab will close some of this gap over time. None of that changes the lesson. The tool alone will not keep you safe. The system you build around it will.
