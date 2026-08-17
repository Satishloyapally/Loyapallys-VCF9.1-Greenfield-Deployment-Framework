#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Stage 00: deploy the VCF Installer OVA to a seed ESXi host.
#
# In a greenfield there is no vCenter yet, so the appliance is pushed
# directly to ESXi with ovftool. All settings come from config/site.yaml;
# passwords come from the environment so nothing secret touches disk.
#
# Usage:
#   export ESXI_PASSWORD='...'                # root password of target_host
#   export INSTALLER_ADMIN_PASSWORD='...'     # admin@local on the appliance
#   export INSTALLER_ROOT_PASSWORD='...'      # root on the appliance
#   scripts/deploy-installer.sh /path/to/VCF-SDDC-Manager-Appliance-9.1.0.0.ova [site.yaml]
# ---------------------------------------------------------------------------
set -euo pipefail

OVA_PATH="${1:?Usage: deploy-installer.sh <installer.ova> [site.yaml]}"
SITE_CONFIG="${2:-$(dirname "$0")/../config/site.yaml}"

: "${ESXI_PASSWORD:?Set ESXI_PASSWORD (root password of the target ESXi host)}"
: "${INSTALLER_ADMIN_PASSWORD:?Set INSTALLER_ADMIN_PASSWORD (admin@local)}"
: "${INSTALLER_ROOT_PASSWORD:?Set INSTALLER_ROOT_PASSWORD (appliance root)}"

command -v ovftool >/dev/null || { echo "ERROR: ovftool not found in PATH"; exit 1; }
[[ -f "$OVA_PATH" ]]          || { echo "ERROR: OVA not found: $OVA_PATH"; exit 1; }
[[ -f "$SITE_CONFIG" ]]       || { echo "ERROR: site definition not found: $SITE_CONFIG"; exit 1; }

# Pull installer settings out of site.yaml
eval "$(python3 - "$SITE_CONFIG" <<'PY'
import sys, yaml, shlex

with open(sys.argv[1]) as f:
    site = yaml.safe_load(f)

s, inst = site["site"], site["installer"]
fqdn = f"{inst['hostname']}.{s['dns_domain']}"

values = {
    "FQDN": fqdn,
    "IP": inst["ip"],
    "NETMASK": inst["netmask"],
    "GATEWAY": inst["gateway"],
    "DOMAIN": s["dns_domain"],
    "DNS": ",".join(s["dns_servers"]),
    "NTP": ",".join(s["ntp_servers"]),
    "TARGET_HOST": inst["target_host"],
    "DATASTORE": inst["target_datastore"],
    "PORTGROUP": inst["target_portgroup"],
}
for key, value in values.items():
    print(f"{key}={shlex.quote(str(value))}")
PY
)"

echo "Deploying VCF Installer '$FQDN' ($IP) to $TARGET_HOST ..."

ovftool \
  --acceptAllEulas \
  --noSSLVerify \
  --skipManifestCheck \
  --allowExtraConfig \
  --X:injectOvfEnv \
  --powerOn \
  --sourceType=OVA \
  --diskMode=thin \
  --name="${FQDN%%.*}" \
  --datastore="$DATASTORE" \
  --network="$PORTGROUP" \
  --prop:guestinfo.hostname="$FQDN" \
  --prop:guestinfo.ip0="$IP" \
  --prop:guestinfo.netmask0="$NETMASK" \
  --prop:guestinfo.gateway="$GATEWAY" \
  --prop:guestinfo.domain="$DOMAIN" \
  --prop:guestinfo.searchpath="$DOMAIN" \
  --prop:guestinfo.DNS="$DNS" \
  --prop:guestinfo.ntp="$NTP" \
  --prop:guestinfo.ADMIN_USERNAME="admin" \
  --prop:guestinfo.ADMIN_PASSWORD="$INSTALLER_ADMIN_PASSWORD" \
  --prop:guestinfo.ROOT_PASSWORD="$INSTALLER_ROOT_PASSWORD" \
  "$OVA_PATH" \
  "vi://root:${ESXI_PASSWORD}@${TARGET_HOST}"

echo "Waiting for the installer UI to answer on https://$FQDN ..."
for _ in $(seq 1 60); do
  if curl -ks -o /dev/null --max-time 5 "https://$FQDN"; then
    echo "VCF Installer is up: https://$FQDN (log in as admin@local)"
    echo "Next: stage the VCF 9.1 binary bundle in the installer, then run stage 10."
    exit 0
  fi
  sleep 30
done

echo "WARNING: installer did not answer within 30 minutes; check the VM console."
exit 1
