# vpskit Architecture

> Status: backfilled during CodeStable onboard
> Created: 2026-06-08

## 1. Project Summary

vpskit is a Bash-based local terminal toolkit for VPS setup, security,
application deployment, status checks, backup/restore, security audit, and
settings management. It can run from a local checkout or from the GitHub raw
entrypoint:

```bash
bash <(curl -sL https://raw.githubusercontent.com/mariusdjen/vpskit/main/vpskit.sh)
```

The target VPS distributions are Ubuntu, Debian, AlmaLinux, Rocky Linux,
CentOS, and Fedora. Local execution supports macOS, Linux, and Windows through
Git Bash or WSL.

## 2. Core Concepts

- Single entrypoint: `vpskit.sh` shows the interactive menu and dispatches
  `setup`, `deploy`, `status`, `backup`, `security`, and `settings` commands.
- Local session: scripts persist connection details in `~/.ssh/.vpskit-local`
  and related settings files so follow-up workflows can reuse the VPS session.
- Remote execution: workflows generate temporary Bash scripts locally, transfer
  them with `scp`, and execute them through `ssh`.
- Progress files: setup uses `/root/.vpskit-progress`; deployment uses
  per-application `.deploy-progress` files under the remote app directory.
  Setup now writes event-style progress lines while retaining read
  compatibility with older single-line step markers.
- Deployment metadata: successful deploy writes per-application files under
  `~USER/apps/APP/`, including `.deploy-domain`, `.deploy-port`,
  `.deploy-branch`, `.deploy-type`, and `.deploy-health-url/status/code/message`.
  Health status is `ok` for HTTP 2xx/3xx and `warn` for curl `000` or HTTP
  4xx/5xx.
- Backup metadata bundle: application backups preserve deploy metadata files
  when present, including `.deploy-branch`, `.deploy-type`, and
  `.deploy-health-url/status/code/message`, while keeping legacy
  `deploy-domain` and `deploy-port` archive entries compatible.
- i18n: `lang.sh` loads local, cached, or remote language files and injects
  message variables into generated remote scripts. The default language is
  Chinese (`zh`); English and French remain available fallbacks.
- Runtime core: `lib/runtime.sh` provides shared Bash helpers for prompt/menu
  input, command execution, error reporting, degradation warnings, and step
  progress events.
- Remote execution core: `lib/remote_exec.sh` prepares generated remote
  scripts, replaces placeholders, uploads them, executes them through SSH, and
  cleans remote temp files with explicit phase return codes.

## 3. Module Index

- `vpskit.sh`: CLI/menu entrypoint. It runs local scripts from a checkout or
  downloads child scripts from GitHub raw, validates downloaded Bash syntax,
  and executes the requested workflow.
- `setup.sh`: VPS bootstrap and hardening. It detects local OS, collects SSH
  details, creates the local session, prepares the generated remote script with
  `lib/remote_exec.sh`, and runs the remote setup flow across Debian/RHEL-family
  distributions with event-style step progress.
- `deploy.sh`: application deployment. It reuses the local session, loads
  `lib/remote_exec.sh` for rollback/update/main deploy remote execution,
  handles Git repositories, Docker Compose or Dockerfile deployments, Caddy
  configuration, update, rollback, deployment progress tracking, deployment
  metadata, and health check metadata.
- `status.sh`: status reporting. It checks VPS state, Docker applications,
  Caddy routing, related remote status data, and deploy health metadata.
- `backup.sh`: backup and restore. It loads `lib/remote_exec.sh`, collects
  application `.env` files, Docker volumes, Caddy configuration, deploy
  metadata, health metadata, and restore inputs.
- `security.sh`: security audit workflow. It loads `lib/remote_exec.sh`,
  supports interactive and parameterized connection modes, and includes deploy
  health metadata in its audit output.
- `settings.sh`: local settings workflow. It loads `lib/remote_exec.sh`,
  manages SSH shortcuts, local session state, language settings, automatic
  deployment settings, and remote backup/rclone configuration.
- `lang.sh` and `lang/`: language loading and message catalog support for local
  and remote script text. `lang/zh.sh` inherits the full English message set
  and overrides the core user-facing flow in Chinese.
- `lib/runtime.sh`: shared runtime layer for user input, menu selection,
  command execution, error codes, degradation warnings, and step status
  tracking. `vpskit.sh` loads it locally from `lib/runtime.sh`; curl mode
  downloads and syntax-checks `lib/runtime.sh` before sourcing it.
- `lib/remote_exec.sh`: shared remote execution layer for generated Bash
  scripts. It prepares scripts with language injection and placeholder
  replacement, uses `ssh/scp` with `BatchMode=yes` and `ConnectTimeout`, creates
  remote temp scripts with `mktemp /tmp/vps-XXXXXXXXXX.sh`, executes with
  `sudo bash` or `bash`, and performs cleanup as a separate phase.
- `docs/`: public static website assets plus the older
  `docs/architecture.md` setup-focused architecture note.
- `.github/workflows/shellcheck.yml`: CI syntax and ShellCheck workflow.

## 4. Existing Architecture Material

`docs/architecture.md` is valid setup/bootstrap subsystem documentation, not a
full-system architecture entry. It describes the `setup.sh` flow: local
preparation, remote security setup, progress resume behavior, and Debian/RHEL
package/firewall/service abstractions.

Keep that file in place as public/project documentation. Use it as source
material when backfilling a fuller setup module document under
`.codestable/architecture/`.

## 5. Known Constraints

- User-facing script text is expected to be French with accents.
- Commit messages are expected to be English.
- Status markers use ASCII labels such as `[INFO]`, `[OK]`, `[WARN]`, `[ERR]`,
  and `[>]`.
- Remote scripts should be written to temporary files, copied with `scp`, and
  executed with `ssh`.
- Template placeholders use `__NAME__` style replacement and `sed` with `|` as
  delimiter.
- Configuration reads should use `grep` and `cut` rather than `source` or
  `eval`.
- Sensitive files such as local session, S3 settings, and application `.env`
  files must remain private.
- Shared Bash modules belong under `lib/`; top-level shell scripts are reserved
  for user-facing workflow entrypoints.
- User input and menus should use runtime helpers (`vk_prompt`, `vk_confirm`,
  `vk_menu`) when touched, so interactive flows have explicit exit paths,
  retry limits, and non-interactive failure behavior.
- New or changed user-facing text should include Chinese (`zh`) wording first,
  while preserving English and French fallback behavior.
- Runtime failures should include a numeric code, a code name, a step id, and a
  human-readable message. Step progress events use
  `timestamp|step_id|status|code|message` while preserving read compatibility
  with older one-line step markers.
- Remote execution failures use stable phase codes: `20` local script
  generation/preparation failure, `21` placeholder replacement failure, `22`
  remote `mktemp` failure, `23` upload failure, `24` chmod or remote execution
  failure, and `25` cleanup failure after successful execution.
- Remote cleanup must be attempted after upload or execution failures, but a
  cleanup result must not hide a failed main execution. A cleanup-only failure
  returns `25` and should be reported as diagnostic debt, not as full success.
- `status.sh`, `setup.sh`, `deploy.sh`, `backup.sh`, `security.sh`, and
  `settings.sh` use `lib/remote_exec.sh` for generated remote scripts.
  Extra file transfers, such as restore tarball upload or backup archive
  download, remain explicit `scp` operations with BatchMode and connection
  timeout options.
- `setup.sh` consumes `lib/remote_exec.sh` for remote setup execution. Its
  remote progress file writes `timestamp|step_id|status|code|message` events,
  treats older one-line `step_id` markers as completed, and renders the final
  setup summary from the last event state instead of hard-coding every component
  as `[OK]`.
- Setup summary status has user-visible semantics: `done` renders `[OK]`,
  `degraded` renders `[WARN]`, `skipped` renders `[SKIP]`, and `failed` renders
  `[ERR]`. Skipped or degraded setup work must not be reported as fully
  completed.
- `deploy.sh` must not reintroduce the old combined local sequence of remote
  `mktemp`, `scp`, `chmod 700`, `sudo bash`, and `rm -f` for rollback, update,
  or main deploy generated scripts.
- Deploy Caddy configuration changes are critical: `caddy validate` or
  `systemctl reload caddy` failure must restore the backup Caddyfile, exit with
  code `34`, and avoid marking `step_caddy` as done.
- Deploy health checks are currently advisory, not required health gates:
  curl `000` and HTTP 4xx/5xx persist as `warn` metadata while deployment can
  continue.
- Status and security consume deploy health metadata for visibility. Missing
  metadata remains compatible with old deployments; `warn` health is visible
  but does not block the status/security workflow.
- Backup and remote-backup cron preserve deploy metadata files when present.
  Database dump failures remain warning-level fallbacks when volume archives
  are still produced.

## 6. Verification Surface

The project verification entrypoint is:

```bash
bash tests/run_all.sh
```

That harness runs the Bash syntax matrix for top-level scripts, shared libs,
language files, and tests; then runs all feature tests under `tests/test_*.sh`;
then validates CodeStable feature YAML and roadmap YAML with
`.codestable/tools/validate-yaml.py`.

CI calls `bash tests/run_all.sh` and keeps ShellCheck as a separate lint step
with warning severity. The harness does not require real VPS, S3, or GitHub SSH
credentials.
