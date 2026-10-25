# Modernization: what stays on VMware, what moves

Hybrid Platform Lab deliberately supports three backends - vSphere, Proxmox
and Azure - because most real estates are mid-migration, not fully on one
platform. This note is the decision table for *which workload goes where*,
written from the perspective of someone using this API to stand up a
development or validation environment, not a from-scratch architecture
redesign.

## Decision table

| Workload | Stay on VMware (vSphere) | Move to containers | Move to Azure |
|---|---|---|---|
| Stateless web/API service, horizontally scaled | No | **Yes** - containers are the better fit: faster to provision, scale, and tear down than a VM clone, and this is exactly the workload container orchestration was built for. | Only if it needs to sit next to other Azure-native services it already depends on. |
| Legacy Windows app tied to a specific OS/IIS config, no owner left to re-platform it | **Yes** - `windows-server-2022-vsphere` exists in the catalog for exactly this. Re-platforming an app nobody maintains is a project of its own, not a side effect of a VM move. | No - the app wasn't built to be containerized and no one is funding that work. | No, for the same reason - "move the VM" and "re-platform the app" are different projects; don't conflate them. |
| Short-lived dev/test environment, torn down within hours or days | **Yes, today** - `ubuntu-22.04-vsphere`/`windows-server-2022-vsphere` via `New-LabVM`, with `ttl_hours` tracked on the environment record so it's visible when it should be reclaimed. | Would be a better fit long-term (near-instant provisioning, no clone/snapshot overhead) but isn't built here - see "Not yet built" below. | Viable if the team's dev workflow already lives in Azure; otherwise adds a second cloud to learn for no gain over the existing vSphere estate. |
| Database or stateful service with strict I/O/latency requirements | **Yes** - keep it on dedicated, well-understood vSphere storage rather than re-architecting storage guarantees for a migration that doesn't need to happen. | No - containers don't remove the underlying storage/latency problem; it still needs to land somewhere with the same guarantees. | Only with a deliberate re-architecture (managed DB service, Azure-native storage) - not a lift-and-shift. |
| Burst/seasonal capacity (e.g. an event, a batch job once a quarter) | No - paying for standing vSphere capacity for something used occasionally is the exact waste cloud elasticity solves. | Possible if the workload is already containerized and the cluster can burst. | **Yes** - this is the textbook cloud-bursting case: pay only while it's running, via `ubuntu-22.04-azure` in the catalog. |
| Compliance-bound workload with data residency or an existing on-prem audit trail that's expensive to re-establish | **Yes** - moving it anywhere means re-proving the compliance posture from scratch; don't do that without a compliance-driven reason to. | No, same reason. | No, same reason, unless the compliance requirement itself is what's driving the move (e.g. a mandate to use a specific Azure region/service). |
| Networking/security appliance (firewall VM, load balancer appliance) tightly coupled to the existing vSphere network | **Yes** - these are usually vendor appliances sold as VMs; there is often no containerized or Azure-native equivalent that's a drop-in replacement. | No. | Only as part of a broader network redesign, not in isolation. |
| New internal tool, greenfield, no existing dependency on vSphere | No reason to put it there. | **Yes**, if the team already runs a container platform - fastest path from code to a running instance. | **Yes**, if the team is Azure-first - either is reasonable; pick whichever the team already operates. |

## The general pattern

- **Stay on VMware** when the workload is: legacy and not worth
  re-platforming, storage/latency-sensitive in a way that's already solved
  there, tied to a vendor appliance, or compliance-anchored to the existing
  environment.
- **Move to containers** when the workload is: stateless, horizontally
  scaled, and already (or trivially) containerized - the operational win is
  in provisioning speed and density, not in "cloud" per se.
- **Move to Azure** when the workload needs elasticity this estate doesn't
  have (burst/seasonal load), or when it's new and the team is already
  Azure-native.
- Across all three: **the catalog in `api/app/catalog.py` is where this
  decision becomes operational**, not aspirational. Adding a workload type to
  this platform means adding a template there that points at the right
  backend - the decision table above is what should drive that addition, not
  the other way around.

## Not yet built

This repository's Azure support (`azure-vm` module, `AzureBackend`) already
covers the "move to Azure" path at the infrastructure level. What it
deliberately doesn't attempt:

- **A container backend.** Nothing here provisions a Kubernetes namespace or
  a container instance - the catalog only ever produces a VM, on one of the
  three backends. Adding one would mean a fourth backend
  (`app/backends/containers.py`) behind the same `ProvisioningBackend`
  interface the other three already implement, likely targeting a namespace
  or a managed container service rather than a VM at all.
- **An automated migration workflow.** This platform provisions *new*
  environments; it has no opinion on migrating an existing VM's workload off
  vSphere. That's a separate, workload-specific project once the decision
  table above says a given workload should move.
