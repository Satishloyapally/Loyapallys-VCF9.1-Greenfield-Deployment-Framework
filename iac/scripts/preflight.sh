#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Greenfield preflight validation.
#
# Reads config/site.yaml and verifies the environment prerequisites that
# cause almost every failed VCF bring-up when they are missing:
#
#   1. Forward DNS for every FQDN in the site definition
#   2. Reverse DNS for every IP that has a known FQDN
#   3. NTP reachability from this machine
#   4. ESXi hosts answering on 443
#
# Run this BEFORE stage 00 and again before stage 10. Exit code is non-zero
# if any check fails.
#
# Usage: scripts/preflight.sh [path/to/site.yaml]
# ---------------------------------------------------------------------------
set -uo pipefail

SITE_CONFIG="${1:-$(dirname "$0")/../config/site.yaml}"

if [[ ! -f "$SITE_CONFIG" ]]; then
  echo "ERROR: site definition not found at $SITE_CONFIG"
  echo "       cp config/site.example.yaml config/site.yaml and edit it first."
  exit 1
fi

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "ERROR: python3 with PyYAML is required (pip3 install pyyaml)."
  exit 1
fi

# Flatten the site definition into "CHECK|ARG1|ARG2" lines.
mapfile -t CHECKS < <(python3 - "$SITE_CONFIG" <<'PY'
import sys, yaml

with open(sys.argv[1]) as f:
    site = yaml.safe_load(f)

domain = site["site"]["dns_domain"]
checks = []

def fqdn(name):
    return name if "." in name else f"{name}.{domain}"

# NTP + DNS servers
for ntp in site["site"].get("ntp_servers", []):
    checks.append(("NTP", ntp, ""))

# Installer
inst = site.get("installer", {})
if inst:
    checks.append(("FORWARD", fqdn(inst["hostname"]), inst.get("ip", "")))
    checks.append(("FORWARD", inst["target_host"], ""))

md = site.get("management_domain", {})

# Seed hosts: DNS + port 443
for host in md.get("hosts", []):
    checks.append(("FORWARD", host, ""))
    checks.append(("PORT", host, "443"))

# Appliances (forward records only; IPs are allocated by the installer)
names = [md.get("sddc_manager", {}).get("hostname"),
         md.get("vcenter", {}).get("hostname"),
         md.get("nsx", {}).get("vip_fqdn")]
names += md.get("nsx", {}).get("manager_hostnames", [])
for node in (md.get("operations") or {}).get("nodes", []):
    names.append(node.get("hostname"))
for key in ("operations_collector", "fleet_management", "automation"):
    names.append((md.get(key) or {}).get("hostname"))
for name in names:
    if name:
        checks.append(("FORWARD", fqdn(name), ""))

# Workload domains
for wld in (site.get("workload_domains") or {}).values():
    checks.append(("FORWARD", wld["vcenter"]["fqdn"], wld["vcenter"].get("ip_address", "")))
    checks.append(("FORWARD", wld["nsx"]["vip_fqdn"], wld["nsx"].get("vip_ip", "")))
    for mgr in wld["nsx"].get("managers", []):
        checks.append(("FORWARD", mgr["fqdn"], mgr.get("ip_address", "")))

# Hosts to commission
for host in (site.get("commission_hosts") or {}):
    checks.append(("FORWARD", host, ""))
    checks.append(("PORT", host, "443"))

# Edge nodes
for ec in (site.get("edge_clusters") or {}).values():
    for name, node in ec.get("nodes", {}).items():
        checks.append(("FORWARD", fqdn(name), node.get("management_ip", "")))

for kind, a, b in dict.fromkeys(checks):  # dedupe, keep order
    print(f"{kind}|{a}|{b}")
PY
)

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

echo "Preflight checks for $SITE_CONFIG"
echo "-----------------------------------------------------------------------"

for line in "${CHECKS[@]}"; do
  IFS='|' read -r kind arg1 arg2 <<<"$line"

  case "$kind" in
    FORWARD)
      resolved=$(getent ahostsv4 "$arg1" 2>/dev/null | awk '{print $1; exit}')
      if [[ -z "$resolved" ]]; then
        bad "forward DNS: $arg1 does not resolve"
        continue
      fi
      if [[ -n "$arg2" && "$resolved" != "$arg2" ]]; then
        bad "forward DNS: $arg1 resolves to $resolved, expected $arg2"
        continue
      fi
      ok "forward DNS: $arg1 -> $resolved"
      # Reverse check for the resolved address
      ptr=$(getent hosts "$resolved" 2>/dev/null | awk '{print $2; exit}')
      if [[ "${ptr%.}" == "${arg1%.}" ]]; then
        ok "reverse DNS: $resolved -> $ptr"
      else
        bad "reverse DNS: $resolved -> ${ptr:-<none>}, expected $arg1"
      fi
      ;;
    PORT)
      if timeout 5 bash -c "exec 3<>/dev/tcp/$arg1/$arg2" 2>/dev/null; then
        ok "reachable: $arg1:$arg2"
      else
        bad "unreachable: $arg1:$arg2"
      fi
      ;;
    NTP)
      if python3 - "$arg1" <<'PY' 2>/dev/null
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)
s.sendto(b'\x1b' + 47 * b'\0', (sys.argv[1], 123))
s.recvfrom(48)
PY
      then
        ok "NTP responding: $arg1"
      else
        bad "NTP not responding: $arg1"
      fi
      ;;
  esac
done

echo "-----------------------------------------------------------------------"
echo "Result: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
