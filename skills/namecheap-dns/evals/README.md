# Evals for the `namecheap-dns` skill

Behavioral tests that check the skill triggers on the right requests and drives
`namecheap.sh` with the correct, safe commands — without touching a real Namecheap account.

## What's here

- **`evals.json`** — the graded suite (prompts, expected output, assertions), in the
  [Agent Skills eval format](https://agentskills.io/skill-creation/evaluating-skills). Four cases:
  1. *list domains* → uses `namecheap.sh domains.getList`
  2. *view records* → uses `domains.dns.getHosts --domain example.com`
  3. *remove a record* → shows current records **and asks for confirmation** before `dns.removeHost`
     (exercising the "show current records first" and "setHosts replaces ALL" safety rules)
  4. *register a domain* (out of scope) → Claude declines and does **not** drive the skill
- **`run-smoke.sh`** — a zero-dependency runnable smoke check for the same four behaviors.

## Running

**Smoke test (runs today, only needs an authenticated `claude` CLI):**

```bash
bash skills/namecheap-dns/evals/run-smoke.sh
```

It drives the skill via `claude -p --plugin-dir <repo-root>`, asks Claude for the command it
would run (no credentials, no DNS changes), and greps the response. Exit 0 = all pass. Because it
drives the model it needs network + auth and can be mildly sensitive to model behavior, so treat it
as a developer check rather than a hermetic CI gate.

**Graded suite (`evals.json`):** run with the
[`skill-creator` plugin](https://github.com/anthropics/skills/tree/main/skills/skill-creator)
(*"evaluate my namecheap-dns skill"*), or with `claude plugin eval` once it leaves early access.
Both run each prompt with and without the skill and grade the assertions, giving a with/without
pass-rate delta.

## Last verified

All four behaviors were confirmed manually via `claude -p --plugin-dir .` (Opus 4.8): in-scope
prompts triggered the correct subcommands, the destructive case showed current records and asked
for confirmation before `dns.removeHost`, and the registration prompt was correctly declined with
an explanation of the skill's DNS-only scope.
