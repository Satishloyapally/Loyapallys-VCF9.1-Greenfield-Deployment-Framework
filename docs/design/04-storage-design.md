# 04 — Storage Design

VCF greenfield deployments default to **vSAN ESA** (Express Storage
Architecture) as the principal storage for each cluster. This document covers
vSAN ESA sizing, Auto-RAID (new in 9.1), and the supported alternatives.

## Principal storage is immutable per cluster

When a cluster is created, its **principal storage type** is fixed and cannot
be changed later (you can add *additional* datastores, but not change the
principal type). Choose deliberately: vSAN, NFS, VMFS on FC, or vVol.

## vSAN ESA — the greenfield default

vSAN ESA aggregates NVMe TLC devices into a single shared datastore per
cluster. Design points:

- **Devices:** multiple NVMe TLC devices per node; performance **Class F**
  (100000–349999 IOPS) or higher, endurance **≥ 3 DWPD**
  (`VCF-VSAN-ESA-RCMD-CFG-001`). Smaller drives cap capacity; very large
  drives enlarge the capacity fault domain on failure. Size with the
  [vSAN Sizer](https://vcf.broadcom.com/tools/vsansizer/home).
- **Storage traffic separation** is recommended for dedicated vSAN storage
  clusters.

### Auto-RAID (new in VCF 9.1)

New vSAN ESA clusters in 9.1 are **Auto-RAID by default**: vSAN dynamically
selects the most efficient, resilient layout (RAID-1 vs RAID-5 vs RAID-6)
based on cluster topology instead of a fixed, admin-chosen policy.

- The new **Effective Capacity** view (Auto-RAID only) shows usable capacity
  after space efficiency and **automatically reserves** free space for
  operations and host rebuilds — the old **"reserved capacity" / "host
  rebuild reserve" / "slack space"** knobs are gone. You can safely use all
  the free capacity vSAN advertises.
- Do **not** enable the legacy "Host Rebuild Reserve" on a 4-node cluster with
  Auto-Policy — it prevents vSAN from using space-efficient RAID-5
  (`VCF-VSAN-...`).

### FTT → RAID → minimum host count

This is the critical sizing decision. Provide enough hosts to **re-protect**
after a sustained failure, not just the bare minimum to store data:

| FTT | RAID | Min hosts to store | **Recommended min (re-protect / N+1)** |
|-----|------|--------------------|----------------------------------------|
| 1 | RAID-1 (mirror) | 3 | 3 (2-node + witness for ROBO) |
| 1 | RAID-5 (2+1 erasure) | 3 | **4** |
| 2 | RAID-6 (4+2 erasure) | 6 | **7** |

Why the extra host:
- A **4-node** cluster keeps RAID-5 (2+1) after one host is lost and can
  rebuild — the recommended N+1 minimum (`VCF-VSAN-ESA-RCMD-CFG-004`).
- A **6-node** cluster *can* form RAID-6 but a single sustained host loss
  drops it below the 4+2 fault domains; Auto-RAID may restripe down to RAID-5
  (FTT=2 → FTT=1). Use **7 nodes** so FTT=2 re-protects.
- The **management domain requires ≥ 4 hosts**; workload vSAN clusters ≥ 3
  (4 recommended).

## Alternatives to vSAN

| Type | Min hosts | Notes |
|------|-----------|-------|
| **vSAN ESA** | 3 (4 rec.) | Default; Auto-RAID; ESA ReadyNodes |
| **vSAN OSA** | 3 (4 rec.) | Older architecture; set `esa_enabled = false` |
| **NFS** | 2 | External filer; needs a network pool with the NFS network |
| **VMFS on FC** | 2 | Consumed (not created) by VCF |
| **vVol** | 2 | Requires a VASA provider |
| **vSAN stretched** | 3 per AZ **+ witness** | Metro HA; witness in a third site/zone |
| **2-node (ROBO)** | 2 **+ witness** | Edge/branch; RAID-1 mirror |

A **network pool** must include the relevant storage networks (vSAN and/or
NFS) before hosts are commissioned into it (see stage 20).

## How this framework expresses it

- `management_domain.vsan` and each workload `clusters.*.vsan` block set
  `esa_enabled`, `failures_to_tolerate`, and (optionally) dedup — driving the
  `vcf_instance` / `vcf_domain` vSAN configuration.
- Host counts come from your `hosts` / `commission_hosts` lists — size them
  per the table above (4 for FTT=1, 7 for FTT=2).

## Sources

- [Single-Rack vSAN ESA Storage Model](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/design/design-library/storage-models-9-x/standard-vsan-storage-model/single-rack-storage-models/vsan-storage-cluster-storage-model.html)
- [Auto-RAID & Effective Capacity in vSAN for VCF 9.1](https://blogs.vmware.com/cloud-foundation/2026/05/11/effective-capacity-view-in-vsan-for-vcf-9-1/)
- [vSAN Availability Technologies](https://www.vmware.com/docs/vmw-vSAN-Availability-Technologies)
