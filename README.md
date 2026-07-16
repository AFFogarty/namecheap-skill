# Namecheap DNS Management Skill

An [agent skill](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) for managing DNS records via the [Namecheap API](https://www.namecheap.com/support/api/methods/). It follows the [Agent Skills](https://agentskills.io) open standard, so it works with GitHub Copilot (CLI, cloud agent, and VS Code agent mode) and with [Claude Code](https://code.claude.com/docs) — installable as a plugin or a standalone skill (see [With Claude Code](#with-claude-code)).

## Repository structure

```
.
├── README.md
└── skills/
    └── namecheap-dns/
        ├── SKILL.md              # Skill definition (name, description, workflow)
        ├── namecheap.sh          # CLI wrapper script for the Namecheap API
        └── references/
            └── namecheap-api.md  # API reference documentation
```

## Installation

### With GitHub CLI (recommended)

> [!NOTE]
> `gh skill` is in public preview. Update GitHub CLI to version 2.90.0 or later.

```bash
# Preview the skill before installing (inspect it for safety)
gh skill preview brunoborges/namecheap-skill namecheap-dns

# Install the skill
gh skill install brunoborges/namecheap-skill namecheap-dns
```

By default the skill installs for Copilot at project scope. To install it as a personal skill shared across all projects, use `--scope user`:

```bash
gh skill install brunoborges/namecheap-skill namecheap-dns --scope user
```

Pin to a specific version or commit so it is skipped during updates:

```bash
gh skill install brunoborges/namecheap-skill namecheap-dns --pin v1.0.0
```

Check for and apply upstream updates later with:

```bash
gh skill update namecheap-dns
```

### With Claude Code

Install as a plugin from the marketplace bundled in this repo:

```bash
# In Claude Code, add the marketplace, then install the plugin:
/plugin marketplace add brunoborges/namecheap-skill
/plugin install namecheap-dns@namecheap-skill
```

Then ask in natural language (for example, *"list my Namecheap domains"*) or invoke the
namespaced command `/namecheap-dns:namecheap-dns`.

Prefer a standalone skill instead of a plugin? Copy the skill directory into Claude Code's
skills folder:

```bash
git clone https://github.com/brunoborges/namecheap-skill.git

# Personal skill (available in all projects)
cp -r namecheap-skill/skills/namecheap-dns ~/.claude/skills/

# Project skill (single repository)
cp -r namecheap-skill/skills/namecheap-dns .claude/skills/
```

### Manual installation

Copy the `skills/namecheap-dns` directory into one of the following locations:

- **Project skill** (single repository): `.github/skills/`, `.claude/skills/`, or `.agents/skills/`
- **Personal skill** (shared across projects): `~/.copilot/skills/`, `~/.claude/skills/`, or `~/.agents/skills/`

```bash
git clone https://github.com/brunoborges/namecheap-skill.git
cp -r namecheap-skill/skills/namecheap-dns ~/.copilot/skills/
```

## Prerequisites

1. A Namecheap account with domains
2. API access enabled at https://ap.www.namecheap.com/settings/tools/apiaccess/
3. Your public IP address whitelisted in the API settings

## Setup

Once installed, just ask Copilot to set up Namecheap (for example, *"set up the Namecheap DNS skill"*) and it will walk you through the steps below. To run setup manually from the skill directory:

1. Run `bash namecheap.sh public-ip` to see your public IP address
2. Go to https://ap.www.namecheap.com/settings/tools/apiaccess/
3. Enable API access (select **ON**)
4. Add your public IP to the whitelist
5. Copy your API key
6. Run `bash namecheap.sh setup` and enter your username and API key

Credentials are stored in `~/.namecheap-api` with `600` permissions.

## Usage

After installation, ask Copilot in natural language, for example:

- "List my Namecheap domains"
- "Show the DNS records for example.com"
- "Add an A record for www.example.com pointing to 1.2.3.4"
- "Remove the CNAME for blog.example.com"
- "Point example.com at Cloudflare's nameservers"

You can also run the bundled script directly from the skill directory:

```bash
# Show your public IP (needed for whitelisting)
bash namecheap.sh public-ip

# Run setup (configures credentials and tests connection)
bash namecheap.sh setup

# List your domains
bash namecheap.sh domains.getList

# View DNS records
bash namecheap.sh domains.dns.getHosts --domain example.com

# Add a DNS record
bash namecheap.sh dns.addHost --domain example.com --type A --name www --address 1.2.3.4

# Remove a DNS record
bash namecheap.sh dns.removeHost --domain example.com --type A --name www
```

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Configure credentials and test API connection |
| `public-ip` | Show your public IP address |
| `domains.getList` | List all your Namecheap domains |
| `domains.dns.getList` | Get nameservers for a domain |
| `domains.dns.getHosts` | Get DNS records for a domain |
| `domains.dns.setHosts` | Replace all DNS records from a JSON file |
| `domains.dns.setDefault` | Switch a domain to Namecheap default DNS |
| `domains.dns.setCustom` | Switch a domain to custom nameservers |
| `domains.dns.getEmailForwarding` | Get email forwarding rules |
| `domains.dns.setEmailForwarding` | Set email forwarding rules |
| `domains.ns.create` | Create a child nameserver (glue record) |
| `domains.ns.delete` | Delete a child nameserver |
| `domains.ns.getInfo` | Get nameserver info |
| `domains.ns.update` | Update a nameserver's IP |
| `dns.addHost` | Add a single record (preserves existing) |
| `dns.removeHost` | Remove a single record |

## Supported record types

A, AAAA, CNAME, MX, MXE, TXT, URL, URL301, FRAME

## Security

This skill stores your Namecheap API key locally in `~/.namecheap-api` (permissions `600`) and never transmits it anywhere except to Namecheap's API over HTTPS. Always inspect a skill and its scripts before installing — run `gh skill preview` first.
