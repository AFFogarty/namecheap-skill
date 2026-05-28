#!/usr/bin/env bash
set -euo pipefail

# Namecheap API CLI wrapper
# Usage: ./namecheap.sh <command> [options]

NAMECHEAP_API_URL="https://api.namecheap.com/xml.response"
CONFIG_FILE="$HOME/.namecheap-api"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_error() { echo -e "${RED}Error:${NC} $1" >&2; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

# Check if credentials are configured
check_credentials() {
    load_config
    if [[ -z "${NAMECHEAP_API_USER:-}" || -z "${NAMECHEAP_API_KEY:-}" ]]; then
        print_error "Namecheap API credentials not configured."
        echo ""
        echo "Run './namecheap.sh setup' to configure your credentials."
        echo ""
        echo "You need:"
        echo "  1. Your Namecheap username"
        echo "  2. An API key from: https://ap.www.namecheap.com/settings/tools/apiaccess/"
        echo "  3. Your public IP whitelisted in the API settings"
        exit 1
    fi
}

# Get public IP address
get_public_ip() {
    curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "unknown"
}

# Make API request
api_request() {
    local command="$1"
    shift
    local extra_params=("$@")

    check_credentials
    local client_ip
    client_ip=$(get_public_ip)

    local url="${NAMECHEAP_API_URL}?ApiUser=${NAMECHEAP_API_USER}&ApiKey=${NAMECHEAP_API_KEY}&UserName=${NAMECHEAP_API_USER}&Command=namecheap.${command}&ClientIp=${client_ip}"

    for param in "${extra_params[@]}"; do
        url="${url}&${param}"
    done

    local response
    response=$(curl -s "$url")

    # Check for errors in the response
    if echo "$response" | grep -q 'Status="ERROR"'; then
        local error_msg
        error_msg=$(echo "$response" | grep -oP '(?<=<Err Code=")[^"]*"[^>]*>\K[^<]+' 2>/dev/null || echo "$response" | sed -n 's/.*<Err[^>]*>\(.*\)<\/Err>.*/\1/p')
        print_error "API returned error: $error_msg"
        return 1
    fi

    echo "$response"
}

# Parse domain into SLD and TLD
parse_domain() {
    local domain="$1"
    local tld sld

    # Handle multi-part TLDs (e.g., co.uk, com.br)
    if echo "$domain" | grep -qE '\.(co|com|net|org|gov)\.[a-z]{2}$'; then
        tld=$(echo "$domain" | grep -oE '\.[^.]+\.[^.]+$' | sed 's/^\.//')
        sld=$(echo "$domain" | sed "s/\.${tld}$//")
    else
        tld="${domain##*.}"
        sld="${domain%.*}"
    fi

    echo "$sld" "$tld"
}

# Format XML DNS records as a table
format_dns_records() {
    local xml="$1"

    # Extract host records
    echo ""
    printf "%-20s %-8s %-40s %-8s %-6s\n" "HOST" "TYPE" "ADDRESS" "TTL" "MXPREF"
    printf "%-20s %-8s %-40s %-8s %-6s\n" "----" "----" "-------" "---" "------"

    echo "$xml" | grep -oP '<host[^/]*/>' | while read -r line; do
        local name type address ttl mxpref
        name=$(echo "$line" | grep -oP 'Name="\K[^"]+' || echo "")
        type=$(echo "$line" | grep -oP 'Type="\K[^"]+' || echo "")
        address=$(echo "$line" | grep -oP 'Address="\K[^"]+' || echo "")
        ttl=$(echo "$line" | grep -oP 'TTL="\K[^"]+' || echo "1800")
        mxpref=$(echo "$line" | grep -oP 'MXPref="\K[^"]+' || echo "-")

        printf "%-20s %-8s %-40s %-8s %-6s\n" "$name" "$type" "$address" "$ttl" "$mxpref"
    done
    echo ""
}

# Format domains list as a table
format_domains_list() {
    local xml="$1"

    echo ""
    printf "%-30s %-12s %-12s %-10s\n" "DOMAIN" "EXPIRES" "LOCKED" "AUTO-RENEW"
    printf "%-30s %-12s %-12s %-10s\n" "------" "-------" "------" "----------"

    echo "$xml" | grep -oP '<Domain[^/]*/>' | while read -r line; do
        local name expires locked autorenew
        name=$(echo "$line" | grep -oP 'Name="\K[^"]+' || echo "")
        expires=$(echo "$line" | grep -oP 'Expires="\K[^"]+' || echo "")
        locked=$(echo "$line" | grep -oP 'IsLocked="\K[^"]+' || echo "")
        autorenew=$(echo "$line" | grep -oP 'AutoRenew="\K[^"]+' || echo "")

        printf "%-30s %-12s %-12s %-10s\n" "$name" "$expires" "$locked" "$autorenew"
    done
    echo ""
}

# Commands

cmd_setup() {
    echo "=== Namecheap API Setup ==="
    echo ""

    # Show public IP
    local public_ip
    public_ip=$(get_public_ip)
    print_info "Your public IP address is: ${CYAN}${public_ip}${NC}"
    echo ""
    echo "Make sure this IP is whitelisted at:"
    echo "  https://ap.www.namecheap.com/settings/tools/apiaccess/"
    echo ""

    # Check existing config
    if [[ -f "$CONFIG_FILE" ]]; then
        load_config
        if [[ -n "${NAMECHEAP_API_USER:-}" ]]; then
            print_info "Existing configuration found for user: ${NAMECHEAP_API_USER}"
            echo ""

            # Test the connection
            echo "Testing API connection..."
            if api_request "domains.getList" "PageSize=1" > /dev/null 2>&1; then
                print_success "API connection successful!"
            else
                print_error "API connection failed. Please check your credentials and IP whitelist."
            fi
            return 0
        fi
    fi

    # Prompt for credentials
    echo "Enter your Namecheap credentials:"
    echo ""
    read -rp "  API Username: " api_user
    read -rsp "  API Key: " api_key
    echo ""
    echo ""

    if [[ -z "$api_user" || -z "$api_key" ]]; then
        print_error "Both username and API key are required."
        exit 1
    fi

    # Save configuration
    cat > "$CONFIG_FILE" << EOF
NAMECHEAP_API_USER="${api_user}"
NAMECHEAP_API_KEY="${api_key}"
EOF
    chmod 600 "$CONFIG_FILE"
    print_success "Credentials saved to ${CONFIG_FILE}"
    echo ""

    # Test connection
    load_config
    echo "Testing API connection..."
    if api_request "domains.getList" "PageSize=1" > /dev/null 2>&1; then
        print_success "API connection successful!"
    else
        print_warn "API connection failed. Please verify:"
        echo "  1. API access is enabled (ON) at the Namecheap settings page"
        echo "  2. IP address ${public_ip} is whitelisted"
        echo "  3. Your API key is correct"
    fi
}

cmd_domains_list() {
    local list_type="ALL"
    local search_term=""
    local page="1"
    local page_size="20"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) list_type="$2"; shift 2 ;;
            --search) search_term="$2"; shift 2 ;;
            --page) page="$2"; shift 2 ;;
            --page-size) page_size="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local params=("ListType=${list_type}" "Page=${page}" "PageSize=${page_size}")
    if [[ -n "$search_term" ]]; then
        params+=("SearchTerm=${search_term}")
    fi

    print_info "Fetching domain list..."
    local response
    response=$(api_request "domains.getList" "${params[@]}")
    format_domains_list "$response"
}

cmd_dns_get_hosts() {
    local domain=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$domain" ]]; then
        print_error "Domain is required. Usage: ./namecheap.sh domains.dns.getHosts --domain example.com"
        exit 1
    fi

    local sld tld
    read -r sld tld <<< "$(parse_domain "$domain")"

    print_info "Fetching DNS records for ${domain} (SLD=${sld}, TLD=${tld})..."
    local response
    response=$(api_request "domains.dns.getHosts" "SLD=${sld}" "TLD=${tld}")
    format_dns_records "$response"
}

cmd_dns_set_hosts() {
    local domain=""
    local hosts_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            --hosts) hosts_file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$domain" || -z "$hosts_file" ]]; then
        print_error "Both --domain and --hosts are required."
        echo "Usage: ./namecheap.sh domains.dns.setHosts --domain example.com --hosts hosts.json"
        exit 1
    fi

    if [[ ! -f "$hosts_file" ]]; then
        print_error "Hosts file not found: ${hosts_file}"
        exit 1
    fi

    local sld tld
    read -r sld tld <<< "$(parse_domain "$domain")"

    # Build host parameters from JSON file
    local params=("SLD=${sld}" "TLD=${tld}")
    local i=1

    while IFS= read -r line; do
        local hostname recordtype address ttl mxpref
        hostname=$(echo "$line" | grep -oP '"HostName"\s*:\s*"\K[^"]+' || echo "")
        recordtype=$(echo "$line" | grep -oP '"RecordType"\s*:\s*"\K[^"]+' || echo "")
        address=$(echo "$line" | grep -oP '"Address"\s*:\s*"\K[^"]+' || echo "")
        ttl=$(echo "$line" | grep -oP '"TTL"\s*:\s*"\K[^"]+' || echo "1800")
        mxpref=$(echo "$line" | grep -oP '"MXPref"\s*:\s*"\K[^"]+' || echo "")

        if [[ -n "$hostname" && -n "$recordtype" && -n "$address" ]]; then
            params+=("HostName${i}=${hostname}")
            params+=("RecordType${i}=${recordtype}")
            params+=("Address${i}=${address}")
            params+=("TTL${i}=${ttl}")
            if [[ -n "$mxpref" ]]; then
                params+=("MXPref${i}=${mxpref}")
            fi
            ((i++))
        fi
    done < <(python3 -c "
import json, sys
with open('${hosts_file}') as f:
    records = json.load(f)
for r in records:
    print(json.dumps(r))
" 2>/dev/null || jq -c '.[]' "$hosts_file")

    if [[ $i -eq 1 ]]; then
        print_error "No valid host records found in ${hosts_file}"
        exit 1
    fi

    print_info "Setting $((i-1)) DNS records for ${domain}..."
    local response
    response=$(api_request "domains.dns.setHosts" "${params[@]}")

    if echo "$response" | grep -q 'IsSuccess="true"'; then
        print_success "DNS records updated successfully for ${domain}!"
    else
        print_error "Failed to update DNS records."
        echo "$response"
    fi
}

cmd_dns_add_host() {
    local domain="" record_type="" name="" address="" ttl="1800" mxpref=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            --type) record_type="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --address) address="$2"; shift 2 ;;
            --ttl) ttl="$2"; shift 2 ;;
            --mxpref) mxpref="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$domain" || -z "$record_type" || -z "$name" || -z "$address" ]]; then
        print_error "Missing required parameters."
        echo "Usage: ./namecheap.sh dns.addHost --domain example.com --type A --name \"@\" --address \"1.2.3.4\" [--ttl 1800] [--mxpref 10]"
        exit 1
    fi

    local sld tld
    read -r sld tld <<< "$(parse_domain "$domain")"

    # Fetch existing records
    print_info "Fetching existing DNS records for ${domain}..."
    local response
    response=$(api_request "domains.dns.getHosts" "SLD=${sld}" "TLD=${tld}")

    # Build params with existing records + new one
    local params=("SLD=${sld}" "TLD=${tld}")
    local i=1

    # Parse existing records
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        local h_name h_type h_address h_ttl h_mxpref
        h_name=$(echo "$line" | grep -oP 'Name="\K[^"]+' || echo "")
        h_type=$(echo "$line" | grep -oP 'Type="\K[^"]+' || echo "")
        h_address=$(echo "$line" | grep -oP 'Address="\K[^"]+' || echo "")
        h_ttl=$(echo "$line" | grep -oP 'TTL="\K[^"]+' || echo "1800")
        h_mxpref=$(echo "$line" | grep -oP 'MXPref="\K[^"]+' || echo "")

        if [[ -n "$h_name" && -n "$h_type" && -n "$h_address" ]]; then
            params+=("HostName${i}=${h_name}")
            params+=("RecordType${i}=${h_type}")
            params+=("Address${i}=${h_address}")
            params+=("TTL${i}=${h_ttl}")
            if [[ -n "$h_mxpref" && "$h_mxpref" != "0" ]]; then
                params+=("MXPref${i}=${h_mxpref}")
            fi
            ((i++))
        fi
    done < <(echo "$response" | grep -oP '<host[^/]*/>')

    # Add the new record
    params+=("HostName${i}=${name}")
    params+=("RecordType${i}=${record_type}")
    params+=("Address${i}=${address}")
    params+=("TTL${i}=${ttl}")
    if [[ -n "$mxpref" ]]; then
        params+=("MXPref${i}=${mxpref}")
    fi

    print_info "Adding ${record_type} record: ${name} -> ${address}"
    local set_response
    set_response=$(api_request "domains.dns.setHosts" "${params[@]}")

    if echo "$set_response" | grep -q 'IsSuccess="true"'; then
        print_success "DNS record added successfully!"
    else
        print_error "Failed to add DNS record."
        echo "$set_response"
    fi
}

cmd_dns_remove_host() {
    local domain="" record_type="" name="" address=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2 ;;
            --type) record_type="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --address) address="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$domain" || -z "$record_type" || -z "$name" ]]; then
        print_error "Missing required parameters."
        echo "Usage: ./namecheap.sh dns.removeHost --domain example.com --type A --name \"@\" [--address \"1.2.3.4\"]"
        exit 1
    fi

    local sld tld
    read -r sld tld <<< "$(parse_domain "$domain")"

    # Fetch existing records
    print_info "Fetching existing DNS records for ${domain}..."
    local response
    response=$(api_request "domains.dns.getHosts" "SLD=${sld}" "TLD=${tld}")

    # Build params excluding the record to remove
    local params=("SLD=${sld}" "TLD=${tld}")
    local i=1
    local removed=false

    while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        local h_name h_type h_address h_ttl h_mxpref
        h_name=$(echo "$line" | grep -oP 'Name="\K[^"]+' || echo "")
        h_type=$(echo "$line" | grep -oP 'Type="\K[^"]+' || echo "")
        h_address=$(echo "$line" | grep -oP 'Address="\K[^"]+' || echo "")
        h_ttl=$(echo "$line" | grep -oP 'TTL="\K[^"]+' || echo "1800")
        h_mxpref=$(echo "$line" | grep -oP 'MXPref="\K[^"]+' || echo "")

        # Check if this is the record to remove
        if [[ "$h_name" == "$name" && "$h_type" == "$record_type" && "$removed" == "false" ]]; then
            if [[ -z "$address" || "$h_address" == "$address" ]]; then
                removed=true
                print_info "Removing record: ${h_name} ${h_type} ${h_address}"
                continue
            fi
        fi

        if [[ -n "$h_name" && -n "$h_type" && -n "$h_address" ]]; then
            params+=("HostName${i}=${h_name}")
            params+=("RecordType${i}=${h_type}")
            params+=("Address${i}=${h_address}")
            params+=("TTL${i}=${h_ttl}")
            if [[ -n "$h_mxpref" && "$h_mxpref" != "0" ]]; then
                params+=("MXPref${i}=${h_mxpref}")
            fi
            ((i++))
        fi
    done < <(echo "$response" | grep -oP '<host[^/]*/>')

    if [[ "$removed" == "false" ]]; then
        print_error "No matching record found to remove."
        exit 1
    fi

    # If no records left, we still need at least one (Namecheap requirement)
    if [[ $i -eq 1 ]]; then
        print_error "Cannot remove the last DNS record. Namecheap requires at least one record."
        exit 1
    fi

    print_info "Updating DNS records for ${domain}..."
    local set_response
    set_response=$(api_request "domains.dns.setHosts" "${params[@]}")

    if echo "$set_response" | grep -q 'IsSuccess="true"'; then
        print_success "DNS record removed successfully!"
    else
        print_error "Failed to remove DNS record."
        echo "$set_response"
    fi
}

cmd_public_ip() {
    local ip
    ip=$(get_public_ip)
    echo "$ip"
}

# Help
cmd_help() {
    echo "Namecheap DNS Management CLI"
    echo ""
    echo "Usage: ./namecheap.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                    Configure API credentials and test connection"
    echo "  public-ip                Show your public IP address"
    echo "  domains.getList          List your Namecheap domains"
    echo "  domains.dns.getHosts     Get DNS records for a domain"
    echo "  domains.dns.setHosts     Set all DNS records for a domain (from JSON)"
    echo "  dns.addHost              Add a single DNS record (preserves existing)"
    echo "  dns.removeHost           Remove a single DNS record"
    echo ""
    echo "Options:"
    echo "  --domain <domain>        Domain name (e.g., example.com)"
    echo "  --type <type>            Record type (A, AAAA, CNAME, MX, TXT, etc.)"
    echo "  --name <hostname>        Host name (e.g., @, www, mail)"
    echo "  --address <value>        Record value (IP or target)"
    echo "  --ttl <seconds>          TTL in seconds (default: 1800)"
    echo "  --mxpref <priority>      MX preference (for MX records)"
    echo "  --hosts <file.json>      JSON file with host records"
    echo "  --search <term>          Search term for domain list"
    echo "  --page <n>               Page number for domain list"
    echo "  --page-size <n>          Page size for domain list (10-100)"
    echo ""
    echo "Examples:"
    echo "  ./namecheap.sh setup"
    echo "  ./namecheap.sh domains.getList"
    echo "  ./namecheap.sh domains.dns.getHosts --domain example.com"
    echo "  ./namecheap.sh dns.addHost --domain example.com --type A --name www --address 1.2.3.4"
    echo "  ./namecheap.sh dns.removeHost --domain example.com --type A --name www"
}

# Main dispatch
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        setup)                  cmd_setup "$@" ;;
        public-ip)              cmd_public_ip "$@" ;;
        domains.getList)        cmd_domains_list "$@" ;;
        domains.dns.getHosts)   cmd_dns_get_hosts "$@" ;;
        domains.dns.setHosts)   cmd_dns_set_hosts "$@" ;;
        dns.addHost)            cmd_dns_add_host "$@" ;;
        dns.removeHost)         cmd_dns_remove_host "$@" ;;
        help|--help|-h)         cmd_help ;;
        *)
            print_error "Unknown command: ${command}"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
