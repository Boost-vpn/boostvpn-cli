# Boost VPN on Windows

Use this workflow automatically on Windows in both Claude Code and Codex, including the
Codex plugin. Run commands in native Windows PowerShell (`powershell.exe`) or PowerShell
7 on Windows (`pwsh.exe`). The `.sh` helpers are for macOS/Linux only.

## Detect and Locate

Inspect the device without installing or changing services:

```powershell
$env:OS
if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
[Environment]::OSVersion.Version
Get-Command boostcli.exe -CommandType Application -ErrorAction SilentlyContinue
Get-Service boostvpnd -ErrorAction SilentlyContinue
```

The official installer requires x64 Windows 10 1809 / Server 2019 (build 17763) or newer.
Stop on ARM64/x86; do not fall back to Linux packages or amd64 emulation on ARM64.
When starting in Git Bash, switch to native PowerShell. WSL has a separate Linux
environment; use native PowerShell when managing the Windows host VPN.

Resolve the CLI through `Get-Command boostcli.exe`. If it is missing from the current
terminal's PATH, check `boostcli\boostcli.exe` under `$env:ProgramW6432` (when set) or
`$env:ProgramFiles`. Invoke an absolute path with `&`, for example:

```powershell
$boostInstallRoot = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$boostCli = Join-Path $boostInstallRoot 'boostcli\boostcli.exe'
if (Test-Path -LiteralPath $boostCli) { & $boostCli --version }
```

`boostcli --version` returns plain text, not JSON, and does not require the daemon.

Use the resolved executable for subsequent commands. Examples below use `boostcli` for
readability. A missing PATH entry immediately after installation means the terminal may
need reopening; use the absolute path in the same session. Do not reinstall merely to
refresh PATH. If variables do not persist between tool calls, resolve them again.

## Codex Sandbox Access

On native Windows under a Codex sandbox, run all daemon-backed commands (`nodes`,
`status`, `connect`, `disconnect`, `login`, `logout`, and `daemon` commands) outside the
sandbox on their first invocation.

With Codex `exec_command`, use the resolved absolute `boostcli.exe` path and set:

```text
sandbox_permissions: "require_escalated"
```

Provide a concise justification describing the requested Boost operation.

This is a sandbox-boundary approval, not Administrator elevation. Do not add the sandbox
account to the `boostcli` Windows group, restart the service, or reinstall Boost merely
because an in-sandbox command returns `DAEMON_UNREACHABLE` with
`Not allowed to reach the Boost service`.

If sandbox escalation is denied or unavailable, stop and tell the user that the current
permission profile prevents access to the local Boost service. Do not retry repeatedly.

## Install, Upgrade, and Roll Back

For a planning request, report the detected OS/architecture, official installer URL,
version selection, install/data paths below, and whether the service will start. Planning
does not execute the installer. There is no Windows `plan-install` CLI subcommand.

With authorization to install or upgrade, run the official command:

```powershell
irm https://static.getboost.app/boostcli/install.ps1 | iex
```

Repeating this command upgrades the installation. Before upgrading, check connection
status, disconnect normally, and back up custom configuration because installation
replaces the configuration template. The installer requests administrator rights through
UAC after verifying the downloaded package and the daemon's Authenticode signature.
It downloads releases at runtime; neither the skill nor the plugin bundles an installer.
Do not bypass failed checksum, signature, or architecture checks.

Use only the official source. Clear inherited `BOOST_BASE_URL`, `BOOST_LOCAL_ARCHIVE`,
and `BOOST_LOCAL_SUMS` overrides for this invocation, restoring their previous values
afterward if using a persistent shell. Leave `BOOST_VERSION` unset for stable; set
`$env:BOOST_VERSION = 'vX.Y.Z'` only for a version requested or confirmed by the user.
`$env:BOOST_NO_START = '1'` prevents service startup when requested. Scope and restore
these environment changes as well. Unix `BOOST_GROUP` and `BOOST_VPN_CONFIRM` do not
control this Windows workflow; authorization comes from the user's request.

After the installer finishes or reports success, resolve the CLI through both
`Get-Command boostcli.exe` and the default Program Files path described above, including
`ProgramW6432` for a 32-bit process. If it is not immediately visible, retry discovery
for a short bounded period with a defined stopping condition. A transient miss, a stale
PATH, or a partially populated installation directory is not sufficient evidence of
installation failure. Do not reinstall based on a single discovery miss.

Report installation failure only when the installer explicitly reports an error or a
nonzero exit, or bounded discovery still cannot find a runnable CLI. If the shell, tool,
or authorization layer prevents discovery or execution, report that verification is
blocked in the current context rather than treating it as proof of installation failure.
If the user reports that the CLI works, test that claim in the current execution context
and reconcile differences in identity, PATH, or access before contradicting it.

Verify the resolved CLI with `boostcli --version` (plain text, not JSON), then check
`boostcli daemon status --json` and `Get-Service boostvpnd`. Report CLI availability and
service access separately; follow the identity checks below if the daemon is unreachable.
An inactive service is expected when `BOOST_NO_START` was set.

## Login, Nodes, and Connections

Use the native CLI for everyday operations; command arguments and JSON formats match
[usage.md](usage.md):

```powershell
boostcli account --json
boostcli nodes --json
boostcli connect 123 --json  # Replace 123 with a real node_id from the current list.
boostcli status --json
boostcli disconnect --json
boostcli logout --json
```

Before connecting or switching nodes, require a successful `boostcli account --json`
response and apply the [membership policy in SKILL.md](../SKILL.md#nodes-and-connections).
`Ultimate` can use all listed nodes; `Premium` can use only nodes with `tier: Premium`;
`Free` must subscribe in the Boost App before connecting. Filter by entitlement before
country or latency, including when the user supplies a node ID. If account lookup fails
or returns an unknown tier, stop selection and follow [usage.md](usage.md#account-and-node-eligibility);
do not infer entitlement or use a connection attempt as an access test.

Login/logout require authorization. Choose from the eligible nodes using the user's
preferences, and poll `status` after connecting until it reports `connected` or failure.
Login does not automatically connect. Logout disconnects before clearing authorization.
Check `$LASTEXITCODE` immediately after a native command before running another executable.

For QR login, first check `boostcli login --help` for `--png`. Create a unique directory
under `[IO.Path]::GetTempPath()` and run `boostcli login --png <absolute-png-path>` in a
session that streams output while the process stays alive. Filter output before returning
it to the conversation: expose only the PNG path and fixed scan/completion/error messages,
not terminal QR codes, authorization URLs, or account details. Windows paths such as
`C:\...` are valid; do not reuse the Bash wrapper's filter that requires a leading `/`.
Capture the CLI exit code even when piping through a filter.

Display the PNG as soon as `QR code image saved to ...` appears, while the same login
process waits for phone authorization. Use local image display in Codex or Claude Code;
if the client cannot show it to the user, open it with `Start-Process -FilePath <png-path>`.
For a remote/headless session without user-visible images, ask the user to run
`boostcli login` in their own terminal. Clean up temporary PNG/output files after success,
failure, cancellation, or expiry. Stop the login client on cancellation; do not stop the
daemon. Do not retry expired codes without a new user request. After success, check
`boostcli status --json` and report login and connection status separately.

## Diagnostics and Services

There is no native `boostcli doctor` command. For a doctor request, use the detection
checks above, `boostcli --version` (plain text), `boostcli status --json`, and:

```powershell
boostcli daemon status --json
boostcli daemon logs --lines 50 --json
Get-Service boostvpnd
```

If the service exists and is running but the CLI reports `DAEMON_UNREACHABLE`, inspect
the command process's actual Windows identity and named-pipe access context before
diagnosing the installation or desktop user. Read-only identity checks include:

```powershell
[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$env:USERNAME
```

Use the process identity as the authority; the environment variable alone does not
establish it. A sandbox, service-account, or interactive-user mismatch can make the CLI
fail only in the agent's execution context. Report which context actually failed; do not
infer that the user's own terminal is broken. Without explicit user authorization, do
not change local group membership or ACLs, restart or modify services, add a sandbox
account to the Boost user group, or automatically switch to another user identity.

| Item | Windows path/name |
| --- | --- |
| CLI, daemon, engine, Wintun | `%ProgramFiles%\boostcli` (use `%ProgramW6432%` from a 32-bit process) |
| Configuration | `%ProgramData%\boostcli\config\boostvpnd.toml` |
| Login state | `%ProgramData%\boostcli\state` |
| Logs | `%ProgramData%\boostcli\logs` |
| Service | `boostvpnd` |
| IPC endpoint | `\\.\pipe\boostvpnd` (named pipe, not a Unix socket) |

When the daemon is unreachable, inspect `install.log` or `boostvpnd.err` in the logs
directory using Administrator PowerShell; `daemon logs` requires a reachable daemon.
Include only necessary, redacted log excerpts. With authorization for service maintenance,
disconnect first and use Administrator PowerShell:

```powershell
Stop-Service boostvpnd
Start-Service boostvpnd
Restart-Service boostvpnd
```

Choose the one operation requested; do not run all three in sequence. Do not force-kill
`boostvpnd.exe` or `leaf.exe`, because normal shutdown restores routes. Windows uses
service control and named-pipe permissions, not launchd, systemd, or Unix socket groups.

## Uninstall

For full removal, explain that configuration, login state, and logs will also be removed,
then execute the authorized operation in **Administrator PowerShell**:

```powershell
boostcli uninstall --purge
```

If the user requests preserving local data, use `boostcli uninstall` without `--purge`.
Do not use `sudo` or an `uninstall.sh` script. Unlike the installer, `boostcli uninstall`
requires an already elevated terminal; a normal terminal does not automatically show UAC.
If the execution environment cannot provide an elevated terminal, give the user the exact
command to run in Administrator PowerShell and report that removal is still pending.

The CLI disconnects safely before invoking the native uninstaller. Stop if disconnection
fails; do not bypass that failure. If the CLI itself is broken, prefer repairing it. Only
after confirming the VPN is disconnected or safely stopping the service and confirming
the engine has exited, run `& <absolute-path-to-boostvpnd.exe> uninstall --purge` as the
authorized recovery operation. Some running executable files may be removed on reboot;
report a reboot requirement only when the uninstaller reports it.
