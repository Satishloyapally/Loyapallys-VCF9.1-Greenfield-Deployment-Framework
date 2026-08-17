# Manual Deployment Guide (UI-driven)

This guide deploys a greenfield **VMware Cloud Foundation 9.1** fleet
**manually** through the VCF Installer, VCF Operations, and the vSphere
Client — no Terraform. It follows the exact same Broadcom sequence as the
automated [deployment-runbook.md](deployment-runbook.md), so you can:

- deploy without the IaC toolchain, or
- understand precisely what each Terraform stage automates, or
- perform the two steps that are **always** manual (depot/binaries and fleet
  licensing) even when you automate the rest.

Each phase below notes the **Terraform stage** that automates it.

> Prerequisites first: complete [prerequisites.md](prerequisites.md) and, if
> you have the repo, run `make preflight` to validate DNS (forward + reverse),
> NTP, and host reachability. Most failed deployments trace back to DNS.

## Sequence at a glance

| # | Broadcom step | UI / tool | Automated by |
|---|---------------|-----------|--------------|
| 1 | Deploy VCF Installer appliance | ovftool / ESXi host client | `iac/stages/00-installer` |
| 2 | Depot + binaries + activation | VCF Installer UI | *manual only* |
| 3 | Management domain bring-up | VCF Installer wizard | `iac/stages/10-management-domain` |
| 4 | License & register fleet | VCF Operations UI | *manual only* |
| 5 | Create network pool | vSphere Client | `iac/stages/20-network-pools` |
| 6 | Commission ESX hosts | vSphere Client (Global Inventory) | `iac/stages/30-host-commission` |
| 7 | Create VI workload domain | VCF Operations | `iac/stages/40-workload-domain` |
| 8 | NSX Edge cluster (Tier-0/BGP) | vSphere Client / NSX | `iac/stages/50-edge-cluster` |
| 9 | Activate vSphere Supervisor | vSphere Client | `iac/stages/60-supervisor` |

---

## 1. Deploy the VCF Installer appliance

In a greenfield there is no vCenter yet, so push the installer OVA directly to
a seed ESXi host.

1. Download the **VCF 9.1 Installer / SDDC Manager appliance OVA** from the
   Broadcom Support Portal.
2. Deploy it with `ovftool` (or the ESXi host client) to one of the four seed
   hosts, supplying the installer FQDN/IP, netmask, gateway, and the
   `admin@local`/root passwords. Ensure forward + reverse DNS for the
   installer FQDN exist.
3. Power it on and browse to `https://<installer-fqdn>`; log in as
   `admin@local`.

> Automated: `iac/scripts/deploy-installer.sh` + `iac/stages/00-installer`.

## 2. Configure the depot, download binaries, apply the activation code

This step is **always manual** (there is no `vmware/vcf` resource for it).

1. In the Installer UI, open **Depot Settings**. Connect to the **Broadcom
   online depot** with your support credentials, or upload the **offline
   binary bundle** for air-gapped sites.
2. Generate/apply the **activation code** from `vcf.broadcom.com`.
3. **Download all binaries** and wait until every component reports
   **Success**. Bring-up cannot start until the bundle is available.

## 3. Bring up the management domain (deployment wizard)

1. In the Installer, launch the **deployment wizard** → select **VMware Cloud
   Foundation** → **Greenfield** (new fleet / new instance).
2. Choose the deployment model: **Simple** (~7 appliances, lab/dev) or
   **HA** (~13 appliances, production). See
   [design/01-architecture-models.md](../design/01-architecture-models.md).
3. Enter the management-domain specification:
   - **ESX hosts** (the four seed hosts) and their root credentials.
   - **Storage**: vSAN (ESA) is the greenfield default; this becomes the
     immutable principal storage — see [design/04-storage-design.md](../design/04-storage-design.md).
   - **Networks/VLANs**: management, VM/VCF management, vMotion, vSAN, host TEP
     — with subnets, gateways, and **IP inclusion ranges** for vMotion/vSAN/TEP
     (enough addresses for all hosts). See [design/02-network-design.md](../design/02-network-design.md).
   - **Appliance FQDNs**: vCenter, NSX Manager VIP (+ manager nodes), SDDC
     Manager; and the VCF Operations / Operations Collector / Fleet Management
     / Automation hostnames if deploying them.
   - **Passwords** for every appliance (15+ chars; permitted specials only).
4. **Pre-validation** runs automatically — fix every flagged item before
   proceeding.
5. **Deploy.** The Installer provisions in order: **vCenter → vSAN → NSX →
   SDDC Manager → VCF Operations → VCF Automation** (2–4 hours). Monitor in the
   Installer UI.

> Automated: `iac/stages/10-management-domain` (`vcf_instance`). You can export the
> wizard's JSON spec for reuse.

## 4. License and register the fleet (VCF Operations)

Always manual. Before consuming capacity:

1. Open **VCF Operations** from the link in the Installer summary.
2. **Register** VCF Operations with Broadcom Business Services.
3. Add/assign the **VCF fleet license** (and vSphere/vSAN keys if you use
   key-based licensing) with sufficient feature scope.
4. Confirm the **depot** is reachable from VCF Operations for later bundle
   downloads.

## 5. Create a network pool (workload capacity)

A network pool must exist **before** you commission hosts — a host is
commissioned *into* a pool. (A default pool for the management domain is
created during bring-up.)

1. In the **vSphere Client**, open **Global Inventory Lists → Network Pools**
   (or the VCF host-management area).
2. Click **Create Network Pool**. Add the **vMotion** and **vSAN** (and/or
   **NFS/iSCSI**) networks with VLAN, MTU, subnet, gateway, and a
   non-overlapping **IP range**.
3. Save. Pools must not have overlapping IP ranges.

> Automated: `iac/stages/20-network-pools` (`vcf_network_pool`).

## 6. Commission ESX hosts

In VCF 9.1, host commissioning is done from the **vSphere Client** (moved from
SDDC Manager).

1. **vSphere Client → Global Inventory Lists → Hosts → Unassigned Hosts →
   Commission Hosts**.
2. Review the checklist, then **Proceed**.
3. Add hosts (individually or by JSON import). For each: **Host FQDN**
   (matching DNS, including capitalization), **Storage Type**
   (VSAN / VSAN_ESA / VSAN_MAX / VSAN_REMOTE / NFS / VMFS_FC / VVOL),
   **Network Pool**, and **root credentials**.
4. Click **Confirm all Fingerprints** to validate host SSH/SSL thumbprints.
5. **Commission.** Hosts move to the free pool with status **Active** and are
   available for a workload domain.

> Automated: `iac/stages/30-host-commission` (`vcf_host`). Host UUIDs feed stage 40
> automatically via remote state.

## 7. Create a VI workload domain

VCF 9.x creates workload domains from the **VCF Operations** workflow.

1. **VCF Operations → Inventory → (Detailed View)** → expand **VCF
   Instances**, select your instance → **Add Workload Domain → Create New**.
2. Confirm prerequisites → **Proceed**.
3. Enter the **workload domain name** and **deployment type**:
   - **Full**: deploys vCenter + NSX, creates a vSphere cluster, prepares
     hosts for NSX.
   - **Deploy infrastructure**: vCenter + NSX only (add clusters later).
4. Provide the **workload vCenter FQDN** and **SSO** (join management SSO, or
   an isolated SSO domain — see [design/07-security-identity-design.md](../design/07-security-identity-design.md)).
5. Name the **vSphere cluster** to create.
6. Select the **cluster image** (vLCM image; you can reuse the management
   image if hardware matches).
7. Configure **NSX**: deployment size + manager node/VIP FQDNs, and the
   **network connectivity type** (NSX segments or VPC/Transit Gateway) — see
   [design/03-nsx-edge-design.md](../design/03-nsx-edge-design.md).
8. Select the **commissioned hosts** (only Active hosts appear) and finish the
   wizard (1–2 hours).

> Automated: `iac/stages/40-workload-domain` (`vcf_domain`).

## 8. Deploy an NSX Edge cluster (north-south routing)

Edges are deployed **after** the workload domain and provide the Tier-0 +
BGP path that Supervisor ingress/egress depends on.

1. Ensure fabric prerequisites: separate **Host TEP** and **Edge TEP** VLANs
   (routed), an **ASN** reserved for the Tier-0, and two **BGP peers**
   (interface IP, ASN, password) if using dynamic routing.
2. **vSphere Client →** VCF networking → **Configure Centralized Network
   Connectivity with Edge Clusters** (or NSX Manager → create edge cluster).
3. Create the edge cluster: name, **form factor**, **MTU** (1500–9000; 9000
   recommended), **Tier-0 HA** (**Active/Active** for ECMP), routing type
   **BGP**, and per-uplink **BGP Peer IP / ASN / password**.
4. Add **≥ 2 edge nodes**; set management IP/gateway, TEP VLAN/IPs, and the
   NSX-enabled VDS uplinks.
5. Verify **BGP sessions** are established (NSX Manager → Networking → Tier-0 →
   BGP) before continuing.

> Automated: `iac/stages/50-edge-cluster` (`vcf_edge_cluster`). See
> [design/03-nsx-edge-design.md](../design/03-nsx-edge-design.md) for A/A vs A/S,
> eBGP/ASN, and Tier-1 DR-only guidance.

## 9. Activate vSphere Supervisor

Enable Kubernetes on a workload cluster (requires a healthy domain, edge/Tier-0
or VPC, and storage).

1. Create a **subscribed content library** first:
   **vSphere Client → Content Libraries → Create**, subscribed to
   `https://wp-content.vmware.com/supervisor/v1/latest/lib.json`, and let it
   sync.
2. **vSphere Client → Supervisor Management → Get Started** (or right-click the
   cluster → **Activate Supervisor**).
3. Select the **networking stack**: **VCF Networking with VPC** (NSX VPC;
   required for VCF Automation consumption), **NSX with Avi**, or **VDS**
   (VKS clusters only, no vSphere Pods).
4. **Cluster / zones**: name the Supervisor, enable **control-plane HA**,
   select the cluster (and three **vSphere Zones** for zonal HA), optionally a
   lowercase zone name.
5. **Storage policy** for control-plane objects (e.g. a vSAN policy; RAID-5 on
   ≥5-node clusters, RAID-1 on ≤4-node).
6. **Management network**: mode **static**, the VM management port group, a
   block of **5 consecutive IPs**, subnet mask, gateway, DNS/NTP. See
   [design/06-supervisor-design.md](../design/06-supervisor-design.md).
7. **Workload network**: NSX Project + VPC connectivity profile (auto-populated
   for VPC), private VPC block (e.g. `/16`), service CIDR, DNS/NTP.
8. **Control plane size** (Tiny/Small/Medium/Large — scale-up only; Small
   suits most, Medium if adding services), optional API-server DNS name.
9. Finish — activation creates the control-plane VMs and components.
10. Assign the content library:
    **Supervisor Management → Content Distribution**.
11. Create **vSphere Namespaces** (storage, VM classes, content library, RBAC)
    for teams/tenants.

> Automated: `iac/stages/60-supervisor` (`vmware/vsphere` + `vmware/nsxt`).

---

## Manual vs automated — when to use which

- **Manual (this guide):** learning, one-off/PoC, air-gapped sites where you
  prefer clicking, or the two mandatory manual gates (steps 2 and 4).
- **Automated (Terraform):** repeatable, reviewable, version-controlled builds.
  The automation still requires you to perform steps 2 and 4 in the UI.

The two paths are interchangeable per phase — e.g. you can bring up the
management domain manually (step 3) and still create workload domains with
`iac/stages/40-workload-domain`, because both talk to the same SDDC Manager / VCF
Operations APIs.

## Sources

- [Deploy a New VCF Fleet or Instance (Installer wizard)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/deployment/deploying-a-new-vmware-cloud-foundation-or-vmware-vsphere-foundation-private-cloud-/deploy-a-new-vcf-fleet-or-a-new-vcf-instance.html)
- [Commission ESX Hosts](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/host-management/commission-hosts.html)
- [Network Pool Management](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/host-management/about-network-pools.html)
- [Configure Centralized Network Connectivity with Edge Clusters](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/building-your-private-cloud-infrastructure/managing-network-connectivity-in-vcenter/managing-centralized-network-connectivity-with-edge-clusters.html)
- [Deploy a Supervisor with VPC Networking](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/vsphere-supervisor-installation-and-configuration/supervisor-networking-with-virtual-private-clouds/deploy-a-supervisor-with-nsx-vpc.html)
