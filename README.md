# Namecheap DNS Management Skill

A [Copilot CLI](https://github.com/github/awesome-copilot) agent skill for managing DNS records via the [Namecheap API](https://www.namecheap.com/support/api/methods/).

## Structure

```
.
├── SKILL.md              # Skill definition (name, description, workflow)
├── namecheap.sh          # CLI wrapper script for the Namecheap API
├── references/
│   └── namecheap-api.md  # API reference documentation
└── README.md
```

## Prerequisites

1. A Namecheap account with domains
2. API access enabled at https://ap.www.namecheap.com/settings/tools/apiaccess/
3. Your public IP address whitelisted in the API settings

## Quick Start

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

## Setup

1. Run `bash namecheap.sh public-ip` to see your public IP address
2. Go to https://ap.www.namecheap.com/settings/tools/apiaccess/
3. Enable API access (select **ON**)
4. Add your public IP to the whitelist
5. Copy your API key
6. Run `bash namecheap.sh setup` and enter your username and API key

Credentials are stored in `~/.namecheap-api` with `600` permissions.

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Configure credentials and test API connection |
| `public-ip` | Show your public IP address |
| `domains.getList` | List all your Namecheap domains |
| `domains.dns.getHosts` | Get DNS records for a domain |
| `domains.dns.setHosts` | Replace all DNS records from a JSON file |
| `dns.addHost` | Add a single record (preserves existing) |
| `dns.removeHost` | Remove a single record |

## Supported Record Types

A, AAAA, CNAME, MX, MXE, TXT, URL, URL301, FRAME