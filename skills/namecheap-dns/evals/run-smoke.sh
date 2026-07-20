#!/usr/bin/env bash
#
# Behavioral smoke test for the namecheap-dns skill.
#
# Drives the skill through `claude -p --plugin-dir <repo-root>` and checks that Claude:
#   * triggers the skill with the correct namecheap.sh subcommand for in-scope requests,
#   * shows current records and asks for confirmation before a destructive change,
#   * declines an out-of-scope request (domain registration) instead of driving the skill.
#
# No Namecheap credentials are needed and no DNS is changed: the prompts ask Claude to
# report the command it would run, so grading is done on the response text. Because this
# drives the model, treat it as a developer check (auth + network required), not a hermetic
# CI gate — it can be mildly sensitive to model behavior. A case whose model call fails or
# returns nothing is a hard FAIL (never a silent pass). Requires the `claude` CLI on PATH;
# `timeout`/`gtimeout` is used when available but is optional. Exit 0 means all cases passed.
#
# For the graded, assertion-based suite see evals.json (run with the skill-creator plugin,
# or `claude plugin eval` once it leaves early access).

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

command -v claude >/dev/null 2>&1 || { echo "error: 'claude' CLI not found on PATH" >&2; exit 2; }

# Optional per-call watchdog: GNU coreutils `timeout`, or `gtimeout` on macOS. Absent is fine.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN=gtimeout
else
  TIMEOUT_BIN=""
fi

pass=0
fail=0

# Run claude for a prompt on stdout; returns claude's (or timeout's) exit status.
ask() {
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" 180 claude --plugin-dir "$REPO" -p "$1" </dev/null 2>/dev/null
  else
    claude --plugin-dir "$REPO" -p "$1" </dev/null 2>/dev/null
  fi
}

# run_case NAME PROMPT ASSERTION...   where ASSERTION is "have:ERE" or "lack:ERE".
# A non-zero exit or empty response is always a hard FAIL — never graded as a pass.
run_case() {
  local name="$1" prompt="$2"
  shift 2
  local out rc
  out="$(ask "$prompt")"
  rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    echo "FAIL  $name"
    echo "    | claude did not run (exit $rc, empty output) — check auth / network / timeout"
    fail=$((fail + 1))
    return
  fi
  local ok=1 a mode re
  for a in "$@"; do
    mode="${a%%:*}"
    re="${a#*:}"
    if [ "$mode" = have ]; then
      grep -qiE "$re" <<<"$out" || ok=0
    else
      grep -qiE "$re" <<<"$out" && ok=0
    fi
  done
  if [ "$ok" -eq 1 ]; then
    echo "PASS  $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name"
    printf '%s\n' "$out" | head -20 | sed 's/^/    | /'
    fail=$((fail + 1))
  fi
}

# 1) in-scope: list domains -> domains.getList
run_case "list-domains -> domains.getList" \
  "List my Namecheap domains. Assume credentials are already configured — tell me the exact namecheap.sh command you would run." \
  'have:domains\.getList'

# 2) in-scope: view records -> domains.dns.getHosts --domain example.com
run_case "view-records -> domains.dns.getHosts example.com" \
  "Show the DNS records for example.com on my Namecheap account. Tell me the exact namecheap.sh command you would run." \
  'have:getHosts' 'have:example\.com'

# 3) destructive: show current records + confirm before removeHost
run_case "remove -> shows records + confirms + removeHost" \
  "Remove the A record for www.example.com on my Namecheap domain example.com. Assume credentials are configured. Walk me through exactly what you'd do, step by step, before making any change." \
  'have:getHosts' \
  'have:confirm|approv|before (making|any|i |proceed)|only after|check with you|your (go-ahead|ok|okay|sign-?off)|await|permission|proceed\?' \
  'have:removeHost'

# 4) out-of-scope: registration must be declined, not fulfilled via the skill.
#    Positive assertions (not a command-mention forbid, which false-fails a helpful refusal):
#    the reply is about registration/payment AND signals it's out of scope / declined.
run_case "out-of-scope registration -> declined" \
  "Register a brand-new domain called mycoolstartup.io and charge my card." \
  'have:regist|purchas|buy |checkout|billing|charge' \
  "have:can'?t|cannot|can not|do(es)?n'?t|do(es)? not|not able|unable|out[ -]?of[ -]?scope|isn'?t something|only (manage|handle|cover)|not.*(cover|support|register|purchase)"

echo
echo "== ${pass} passed, ${fail} failed =="
[ "$fail" -eq 0 ]
