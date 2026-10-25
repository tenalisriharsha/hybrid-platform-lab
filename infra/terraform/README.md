# Terraform — Platform Infrastructure

Terraform describing the lab's vSphere estate as code: the datacenter,
compute cluster, ESXi hosts, and NAS datastores that `platform-api`'s
inventory mirrors. It deliberately does **not** declare per-host CPU/memory
capacity or individual VMs — those are properties of real hardware and
workloads, observed live through the `HybridPlatformSync` PowerCLI module
(`infra/powershell/`), not something Terraform should invent.

```
infra/terraform/
  modules/vsphere-estate/   Reusable module: datacenter + cluster + hosts + datastores
    tests/                  terraform test suite (mock_provider, no real calls)
  environments/lab/         Root module wiring the module for this lab's topology
```

## Module: `vsphere-estate`

Given a list of hosts and datastores, the module plans:

- one `vsphere_datacenter`
- one `vsphere_compute_cluster` inside it
- one `vsphere_host` per entry in `hosts`, attached to that cluster
- one `vsphere_nas_datastore` per entry in `datastores`, mounted across
  every host

Host passwords are passed as a separate `host_passwords` map (keyed by
hostname) rather than embedded in `hosts`, so `hosts` can stay a
non-sensitive value usable as a `for_each` key while credentials stay
marked `sensitive`.

Variable validation rejects an empty `hosts` list, duplicate hostnames,
duplicate datastore names, and any host missing a matching
`host_passwords` entry.

## Running it

```bash
cd infra/terraform/modules/vsphere-estate
terraform init
terraform validate
terraform test          # mock_provider — no network or vCenter/vcsim call is made

cd ../../environments/lab
terraform init
terraform validate
cp terraform.tfvars.example terraform.tfvars   # fill in real values first
```

**No `terraform plan`/`apply` against a real vCenter or `vcsim` is run in
this repo or its CI.** `terraform validate` only checks the configuration
against the provider's schema offline; `terraform test` runs entirely
against a `mock_provider`, so neither makes a network call or needs real
credentials. `terraform.tfvars.example` holds placeholder values only —
never commit a real `terraform.tfvars`.

## Checks

- `terraform fmt -recursive -check` — formatting
- `terraform validate` — schema/reference correctness, run from both
  `modules/vsphere-estate` and `environments/lab`
- `terraform test` — 6 cases in `modules/vsphere-estate/tests/`, covering
  the expected topology plan and every validation rule
