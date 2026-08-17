#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Collect SSL (SHA-256) and SSH thumbprints from ESXi hosts.
#
# The stages default to skip_host_thumbprint_validation = true for
# convenience. For production, set it to false and record the values this
# script prints as evidence of host identity at commission time.
#
# Usage: scripts/thumbprints.sh host1.example.com [host2.example.com ...]
# ---------------------------------------------------------------------------
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: thumbprints.sh <host-fqdn> [...]"; exit 1; }

for host in "$@"; do
  echo "== $host"

  ssl=$(openssl s_client -connect "$host:443" </dev/null 2>/dev/null \
        | openssl x509 -fingerprint -sha256 -noout 2>/dev/null \
        | cut -d= -f2 || true)
  echo "  SSL  (SHA256): ${ssl:-<unavailable>}"

  ssh=$(ssh-keyscan -t rsa "$host" 2>/dev/null \
        | ssh-keygen -lf - -E sha256 2>/dev/null \
        | awk '{print $2}' || true)
  echo "  SSH  (SHA256): ${ssh:-<unavailable>}"
done
