# Ansible — Platform Configuration

Renders environment-specific configuration for the platform: a Spring Boot
config overlay for `platform-api` and a connection-settings file for the
`HybridPlatformSync` PowerCLI module (`infra/powershell/`), both driven by
the same set of variables so an environment's port, vcsim endpoint, and
sync cadence stay in one place.

```
infra/ansible/
  ansible.cfg
  inventory/hosts.ini           localhost, ansible_connection=local
  playbooks/configure-platform.yml
  roles/platform_config/        templates application.yml + hybrid-platform-sync.json
  tests/run-tests.sh            ansible-lint + a real exercise of the role
```

There are no remote hosts to configure in this lab: the playbook renders
local files under `dist/config/<env>/` (git-ignored, regenerated on every
run) that a deployment step would hand to `platform-api` and to
`HybridPlatformSync`.

## Running it

```bash
cd infra/ansible
ansible-playbook playbooks/configure-platform.yml                       # renders dist/config/lab/
ansible-playbook playbooks/configure-platform.yml --check --diff        # dry run, no files written
ansible-playbook playbooks/configure-platform.yml -e "platform_config_env=staging platform_config_api_port=9090"
```

Variables (see `roles/platform_config/defaults/main.yml`): `platform_config_env`,
`platform_config_api_port`, `platform_config_logging_level_root`,
`platform_config_logging_level_platform`, `platform_config_vcsim_server`,
`platform_config_vcsim_port`, `platform_config_api_base_url`,
`platform_config_sync_interval_seconds`. An `assert` task rejects
out-of-range values (bad port numbers, an unrecognized environment name, a
sync interval under 30s) before anything is written.

## Checks

`tests/run-tests.sh`:

1. `ansible-lint .` — passes at the `production` profile
2. `--check --diff` against a clean output directory — asserts the
   expected changes are reported and that nothing is actually written
3. a real run — asserts the rendered files exist with the expected content
4. a second real run — asserts it is a no-op (idempotent)
5. a run with variable overrides — asserts the overridden environment
   renders distinct, correct output
6. a run with an invalid variable — asserts the role's `assert` task
   rejects it

No real hosts are touched; everything runs against `localhost` with
`ansible_connection=local`.
