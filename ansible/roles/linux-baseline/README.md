# linux-baseline

Applies the hybrid-platform-lab Linux baseline to a Debian/Ubuntu host:

- a local admin user (`linux_baseline_admin_user`) in the configured groups,
  with an optional SSH public key
- baseline packages (`linux_baseline_packages`)
- SSH hardening in `/etc/ssh/sshd_config` (root login and password auth
  disabled, X11 forwarding disabled, auth-tries and idle-timeout limits)
- `chrony` and `sshd` enabled and running
- `node_exporter` (via the distro's `prometheus-node-exporter` package)
  enabled and running, for Prometheus scraping

## Variables

See `defaults/main.yml` for the full list and defaults. The one most worth
overriding per-environment is `linux_baseline_manage_services`: set it to
`false` when the target has no running init system (a plain Docker
container, used in this repo's own test harness) so the role configures
files without trying to start services that cannot run there.

## Usage

```yaml
- hosts: linux_hosts
  become: true
  roles:
    - linux-baseline
```

## Testing

This role is tested against a real (non-systemd) Docker container rather
than Molecule (cut from this project's scope) — see
`scripts/run-ansible-tests.sh`, which starts a container, runs
`ansible-lint`, applies the role twice to confirm the second run reports
`changed=0` (idempotence), and tears the container down.
