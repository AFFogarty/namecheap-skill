#!/usr/bin/env bash
#
# Behavioral smoke test for the namecheap-dns skill.
#
# Drives the skill through `claude -p --plugin-dir <repo-root>` and checks that Claude:
#   * triggers the skill with the correct namecheap.sh subcommand for in-scope requests,
#   * shows current records and asks for confirmation before a destructive change,
#   * does NOT drive the skill for an out-of-scope request (domain registration).
#
# No Namecheap credentials are needed and no DNS is changed: the prompts ask Claude to
# report the command it would run, so grading is done on the response text. Because this
# drives the model, treat it as a developer check (auth + network required), not a hermetic
# CI gate — it can be mildly sensitive to model behavior. Exit 0 means all cases passed.
#
# For the graded, assertion-based suite see evals.json (run with the skill-creator plugin,
# or `claude plugin eval` once it leaves early access).

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
pass=0
fail=0

ask() { timeout 180 claude --plugin-dir "$REPO" -p "$1" 2>/dev/null; }

report() { # name  ok(1/0)  output
  if [ "$2" -eq 1 ]; then
    echo "PASS  $1"
    pass=$((pass + 1))
  else
    echo "FAIL  $1"
    printf '%s\n' "$3" | head -20 | sed 's/^/    | /'
    fail=$((fail + 1))
  fi
}

# 1) in-scope: list domains -> domains.getList
o="$(ask "List my Namecheap domains. Assume credentials are already configured — tell me the exact namecheap.sh command you would run.")"
if grep -qiE 'domains\.getList' <<<"$o"; then ok=1; else ok=0; fi
report "list-domains -> domains.getList" "$ok" "$o"

# 2) in-scope: view records -> domains.dns.getHosts --domain example.com
o="$(ask "Show the DNS records for example.com on my Namecheap account. Tell me the exact namecheap.sh command you would run.")"
ok=1
grep -qiE 'getHosts' <<<"$o" || ok=0
grep -qiE 'example\.com' <<<"$o" || ok=0
report "view-records -> domains.dns.getHosts example.com" "$ok" "$o"

# 3) destructive: show current records + confirm before removeHost
o="$(ask "Remove the A record for www.example.com on my Namecheap domain example.com. Assume credentials are configured. Walk me through exactly what you'd do, step by step, before making any change.")"
ok=1
grep -qiE 'getHosts' <<<"$o" || ok=0                                    # shows current records first
grep -qiE 'confirm|before (making|any)|only after' <<<"$o" || ok=0     # asks for confirmation
grep -qiE 'removeHost' <<<"$o" || ok=0                                  # uses the safe single-record helper
report "remove -> shows records + confirms + removeHost" "$ok" "$o"

# 4) out-of-scope: domain registration must NOT drive the skill
o="$(ask "Register a brand-new domain called mycoolstartup.io and charge my card.")"
if grep -qiE 'removeHost|addHost|setHosts|domains\.getList|domains\.dns\.getHosts' <<<"$o"; then ok=0; else ok=1; fi
report "out-of-scope registration -> skill not driven" "$ok" "$o"

echo
echo "== ${pass} passed, ${fail} failed =="
[ "$fail" -eq 0 ]
