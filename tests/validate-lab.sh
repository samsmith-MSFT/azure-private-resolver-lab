#!/usr/bin/env bash
# validate-lab.sh
#
# Runs the three demo validation queries from inside the corresponding lab VMs.
# This script does NOT run on your local workstation. It assumes you are
# already on the right VM (vm-onprem-client for Demo 1, vm-ubuntu-lab for
# Demos 2 + 3) — connect via Azure serial console or RDP first, then copy
# this script over or run the dig commands inline.

set -euo pipefail

DEMO="${1:-help}"
STORAGE_HOST="${2:-}"
ONPREM_FQDN="${3:-dns.contoso.com}"
BLOCKED_FQDN="${4:-malicious.contoso.com}"
ALLOWED_FQDN="${5:-microsoft.com}"

case "$DEMO" in
  demo1)
    if [ -z "$STORAGE_HOST" ]; then
      echo "Usage: $0 demo1 <storage-host>"
      echo "  e.g.  $0 demo1 stdnslabxxxx.blob.core.windows.net"
      exit 1
    fi
    echo "Demo 1 — Inbound (run from vm-onprem-client)"
    echo "Resolving $STORAGE_HOST ..."
    nslookup "$STORAGE_HOST"
    echo
    echo "Expect: a private IP in 10.0.3.x (NOT a public storage VIP)."
    ;;
  demo2)
    echo "Demo 2 — Outbound (run from vm-ubuntu-lab)"
    echo "Resolving $ONPREM_FQDN ..."
    dig +short "$ONPREM_FQDN" || true
    echo
    echo "Expect: 10.1.1.4 — Azure VM resolving an on-prem zone via the outbound endpoint."
    ;;
  demo3)
    echo "Demo 3 — DNS Security Policy (run from vm-ubuntu-lab)"
    echo
    echo "Allowed query: $ALLOWED_FQDN"
    dig +short "$ALLOWED_FQDN" | head -5 || true
    echo
    echo "Blocked query: $BLOCKED_FQDN"
    dig "$BLOCKED_FQDN" || true
    echo
    echo "Expect:"
    echo "  - $ALLOWED_FQDN resolves normally"
    echo "  - $BLOCKED_FQDN returns SERVFAIL"
    echo "  - Both queries are visible in Log Analytics: DnsResolverQueryLogs"
    ;;
  *)
    cat <<EOF
Usage: $0 {demo1|demo2|demo3} [args...]

  $0 demo1 <storage-host>          # from vm-onprem-client
  $0 demo2 [onprem-fqdn]           # from vm-ubuntu-lab (default: dns.contoso.com)
  $0 demo3 [blocked] [allowed]     # from vm-ubuntu-lab

Connect to the right VM first via Azure portal serial console.
EOF
    ;;
esac
