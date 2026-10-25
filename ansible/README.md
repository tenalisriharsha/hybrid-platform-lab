# Ansible: linux-baseline

One role, `roles/linux-baseline`, applying the hybrid-platform-lab Linux
baseline to a Debian/Ubuntu host: a local admin user, baseline packages, SSH
hardening, and `node_exporter` for Prometheus scraping. See
[`roles/linux-baseline/README.md`](roles/linux-baseline/README.md) for what
it manages and which variables to override.

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.example.ini playbooks/baseline.yml
```

## Tests

```bash
./scripts/run-ansible-tests.sh   # from the repo root
```

Requires Docker. Starts a plain (non-systemd) container, runs `ansible-lint`
against the role and playbook, applies the role twice, and asserts the
second apply reports `changed=0` - the role's idempotence check - before
tearing the container down. `linux_baseline_manage_services` is set `false`
for this run since the container has no init system to start services under;
see the role's README for what that skips and why.

## Layout

```
ansible.cfg              roles_path, inventory default, etc.
requirements.yml          ansible.posix (authorized_key), community.docker (test harness)
inventory/
  hosts.example.ini        template for a real inventory - fill in and never commit real hosts
playbooks/
  baseline.yml              applies linux-baseline to the linux_hosts group
roles/
  linux-baseline/           the role itself
```
