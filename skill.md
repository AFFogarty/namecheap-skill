# Namecheap DNS Management Skill

Use this skill when the user wants to manage DNS records for domains registered with Namecheap. This includes listing domains, viewing DNS records, adding/updating/removing DNS host entries, and setting up API access.

## Triggers

- User mentions "Namecheap", "DNS", "domain records", "A record", "CNAME", "MX record", "TXT record"
- User wants to add, update, or remove DNS entries
- User wants to list their Namecheap domains
- User wants to check or configure Namecheap API access

## Setup Flow

Before executing any Namecheap API commands, the user must provide:

1. **ApiUser** — Their Namecheap username
2. **ApiKey** — Their API key, obtainable at https://ap.www.namecheap.com/settings/tools/apiaccess/
   - The user must enable API access (select ON)
   - The user must whitelist the public IP address of the machine making API calls

### Checking Public IP

To help the user whitelist their IP, run:

```bash
curl -s https://api.ipify.org
```

This returns the machine's public IP address which must be added to the Namecheap API whitelist.

### Credential Storage

Store credentials in `~/.namecheap-api` as environment variables:

```bash
NAMECHEAP_API_USER="username"
NAMECHEAP_API_KEY="api-key"
```

If this file exists, source it before making API calls. If it does not exist, guide the user through setup.

## API Reference

Base URL: `https://api.namecheap.com/xml.response`

All requests require these common parameters:
- `ApiUser` — Namecheap username
- `ApiKey` — API key
- `UserName` — Same as ApiUser
- `ClientIp` — The whitelisted public IP address
- `Command` — The API command to execute

## Available Commands

Use the `namecheap.sh` script in this repository for all API interactions.

### 1. List Domains

```bash
./namecheap.sh domains.getList
```

Optional parameters: `ListType` (ALL|EXPIRING|EXPIRED), `SearchTerm`, `Page`, `PageSize`

### 2. Get DNS Records

```bash
./namecheap.sh domains.dns.getHosts --domain example.com
```

### 3. Set DNS Records

```bash
./namecheap.sh domains.dns.setHosts --domain example.com --hosts hosts.json
```

The `hosts.json` file should contain an array of records:

```json
[
  {"HostName": "@", "RecordType": "A", "Address": "1.2.3.4", "TTL": "1800"},
  {"HostName": "www", "RecordType": "CNAME", "Address": "example.com.", "TTL": "1800"},
  {"HostName": "@", "RecordType": "MX", "Address": "mail.example.com.", "MXPref": "10", "TTL": "1800"},
  {"HostName": "@", "RecordType": "TXT", "Address": "v=spf1 include:_spf.google.com ~all", "TTL": "1800"}
]
```

### 4. Add a Single DNS Record

```bash
./namecheap.sh dns.addHost --domain example.com --type A --name "@" --address "1.2.3.4" --ttl 1800
```

This is a convenience wrapper that:
1. Fetches existing records with `domains.dns.getHosts`
2. Appends the new record
3. Calls `domains.dns.setHosts` with all records

### 5. Remove a DNS Record

```bash
./namecheap.sh dns.removeHost --domain example.com --type A --name "@" --address "1.2.3.4"
```

This is a convenience wrapper that:
1. Fetches existing records with `domains.dns.getHosts`
2. Removes the matching record
3. Calls `domains.dns.setHosts` with remaining records

### 6. Setup / Check Configuration

```bash
./namecheap.sh setup
```

Displays public IP, checks for stored credentials, and validates API access.

## Important Notes

- The `domains.dns.setHosts` API **replaces all records** for a domain. Always fetch existing records first before modifying.
- MX records require the `MXPref` parameter.
- TTL is in seconds (default: 1800).
- Supported record types: A, AAAA, CNAME, MX, MXE, TXT, URL, URL301, FRAME.
- The Namecheap API uses XML responses. The script parses these into readable output.
