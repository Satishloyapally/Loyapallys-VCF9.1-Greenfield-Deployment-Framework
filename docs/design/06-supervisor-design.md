# 06 — vSphere Supervisor Design

vSphere Supervisor (Workload Management) turns a workload-domain cluster into
a Kubernetes platform for vSphere Pods, VMs, and VKS (vSphere Kubernetes
Service) clusters. It is **not a simple toggle** — it depends on a working
workload domain, NSX networking (edge/Tier-0 or VPC), and storage being in
place first (this repo's stage `60`, after `40`/`50`).

## Control plane model (Choice)

Deploy the Supervisor with **one** or **three** control plane VMs; **three is
recommended** for HA.

| Model | Control plane VMs | Protects against |
|-------|-------------------|------------------|
| Single-zone, 1 CP VM | 1 | nothing (dev/test) |
| Single-zone, 3 CP VMs | 3 (one management zone) | node failure, rolling upgrades |
| **Three-zone HA** | 3, **one per vSphere Zone** | a full **cluster/AZ** failure (`VCF-SUP-CP-REQD-CFG-002`) |

- Three CP VMs allow continuous availability during rolling upgrades and
  single-node outages (`VCF-SUP-CP-RCMD-CFG-001`).
- Each CP VM has its own IP; a **floating IP** fronts the active one; a 5th IP
  is reserved for patching → reserve **five consecutive, routable management
  IPs** (`VCF-SUP-CP-REQD-CFG-001`).
- DRS places the CP VMs; in a three-zone deployment each CP VM lands in a
  different zone (each zone = one vSphere cluster = one failure domain).

### Control plane sizing (scale-up only)

| Size | vCPU | RAM | Max vSphere Pods |
|------|------|-----|------------------|
| Tiny | 2 | 8 GB | 1000 |
| Small | 4 | 16 GB | 2000 |
| Medium | 8 | 24 GB | 4000 |
| Large | 16 | 32 GB | 8000 |

You can **only scale up**, never down. Small (3× = 12 vCPU / 48 GB) is a
common starting point (up to 2000 pods); Large (3× = 48 vCPU / 96 GB) for
8000 pods.

## Networking (Choice — must exist before activation)

| Stack | Load balancing |
|-------|----------------|
| **vSphere Distributed Switch (VDS)** | Foundation Load Balancer or Avi |
| **NSX Overlay Segments** | NSX Load Balancer or Avi |
| **NSX VPC** | Avi Load Balancer |

Plan the pod/service/ingress/egress CIDRs:
- **pod CIDR** and **service CIDR** are internal (e.g. `10.244.0.0/20`,
  `10.96.0.0/22`).
- **ingress** and **egress** CIDRs must be **routable and advertised by the
  Tier-0** (BGP) — this is why the edge cluster (stage 50) must be healthy
  first.

## Storage

- **Storage policies** define placement for CP VMs, ephemeral disks, and
  container images (vSAN, VMFS, or NFS).
- For **three-zone** deployments the policies must be **topology-aware** so
  objects honor zone boundaries.

## Content library

- Supervisor/VKS images are decoupled from vCenter updates.
- Create a **subscribed content library** pointing at the Software Depot
  subscription endpoint and assign it to the Supervisor — this feeds
  Kubernetes releases and VM images.

## Backup & DR (design it before you rely on it)

- The **vCenter file-based backup** with the **Supervisor option** captures
  the control-plane state (etcd, Kubernetes CA, infra images, namespaces,
  resource state, Supervisor config).
- It does **not** back up the applications or persistent data **inside** VKS
  clusters — protect those separately with the **Velero Plugin for vSphere**
  (scheduled backups, independent artifact storage, tested restores).
- A Supervisor restore only rebuilds the control plane; networking, storage,
  identity, DNS/NTP must be healthy for it to become usable.

## How this framework expresses it

- `iac/modules/supervisor` (stage 60) enables Workload Management on a chosen
  workload cluster using `vmware/vsphere` + `vmware/nsxt`, subscribes a
  content library, and wires ingress/egress/pod/service CIDRs.
- The `supervisors` block in `site.yaml` selects the workload domain, cluster,
  edge cluster, control-plane size, management network, and CIDRs.

## Sources

- [Supervisor Architecture and Deployment Options](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/vsphere-supervisor-installation-and-configuration/vsphere-supervisor-concepts/supervisor-architecture-and-components/supervisor-architecture.html)
- [High Availability Supervisor Control Plane Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/self-service-iaas-deployment-models/vsphere-supervisor-control-plane-models/high-availability-control-plane-model.html)
- [Change the Control Plane Size of a Supervisor](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/vsphere-supervisor-installation-and-configuration/configuring-and-managing-a-supervisor-cluster/change-the-control-plane-size-on-a-supervisor-cluster.html)
