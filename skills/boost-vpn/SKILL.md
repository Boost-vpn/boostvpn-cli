---
name: boost-vpn
description: Install and manage Boost VPN (boostcli) on macOS, Linux, and Windows from official downloads. Use for Boost VPN installation, upgrades, QR login, server selection, connect/disconnect, diagnostics, and uninstall.
---

# Boost VPN

Manage Boost VPN using the native workflow for the target device. This directory can be
installed as a standalone skill in Claude Code or Codex, or distributed with the Codex plugin.
It does not depend on a project checkout, MCP, or an additional SDK.

## Automatic Platform Selection

Before running any operation, determine the target operating system, CPU architecture,
and available shell from the execution environment. Use read-only detection when needed:
`uname -s` and `uname -m` on macOS/Linux; `$env:OS`, `$env:PROCESSOR_ARCHITEW6432`
(when set, otherwise `$env:PROCESSOR_ARCHITECTURE`) in Windows PowerShell. Select the
workflow automatically; do not ask the user to choose a platform when it is detectable.

| Target device | Execution workflow |
| --- | --- |
| macOS, arm64 or amd64 | Bash wrapper below; official `install.sh`; launchd |
| Linux, arm64 or amd64 | Bash wrapper below; official `install.sh`; systemd |
| Windows, amd64/x64 | Native PowerShell and `boostcli.exe`; read [references/windows.md](references/windows.md) for every operation |

Windows installation uses `irm https://static.getboost.app/boostcli/install.ps1 | iex`.
Windows full removal uses `boostcli uninstall --purge` in an Administrator PowerShell.
It removes configuration, login state, and logs; explain that scope before executing it.
If the user wants to preserve these data, use `boostcli uninstall` instead.

The Bash wrapper and all Bash examples below apply only to macOS/Linux. On Windows,
use the Windows reference for installation, upgrades, login, nodes, connections,
diagnostics, service management, and uninstallation; do not require Bash, `sudo`, or WSL.
Git Bash/MSYS (`MINGW*`, `MSYS*`, `CYGWIN*`) on a Windows device must route to native
PowerShell. WSL is a separate Linux environment: do not install a Linux service there
as a substitute for the Windows host VPN. For remote sessions, detect the remote target.
Stop on unsupported systems or architectures; Windows ARM64/x86 are not supported by
the current official installer. Do not substitute an archive for another architecture.

## Authorization

Read-only operations can run directly. Installation, upgrades, login, logout, uninstall,
and service changes require user authorization. Reuse an explicit request that already
covers the action; do not ask again. Otherwise, explain the specific action and its impact first.
Connecting or switching nodes changes system network routes; follow the user's connection
request, and do not connect automatically after login.

## macOS/Linux Script Location

Set the variable below to the absolute script path within **the directory containing the
SKILL.md you are currently reading**. Do not infer this path from the working directory.
If shell variables do not persist between tool calls, use the absolute path directly.

```bash
BOOST_VPN_SCRIPT="/absolute/path/to/boost-vpn/scripts/boost-vpn.sh"
bash "$BOOST_VPN_SCRIPT" doctor
```

Set `BOOST_VPN_CONFIRM=1` only for the authorized command. Do not export it globally.
Do not run the entire wrapper with `sudo`; it elevates privileges internally only for
installation and uninstallation.

On macOS, when the wrapper is running as the user of the local graphical login session, installation
uses AppleScript's `do shell script … with administrator privileges`. macOS displays its
system **password dialog** (also called the macOS administrator authorization dialog),
provided by Authorization Services. Tell the user to enter the administrator password
only in that system dialog; never collect it in chat, script arguments, environment variables,
or a custom password-input dialog. The dialog
may reuse a recent authorization and therefore does not necessarily appear on every run.
SSH, missing `osascript`, or a console login owned by a different user use the normal
terminal `sudo` path. If this agent session cannot expose an interactive terminal prompt,
have the user run the command in their own terminal; never collect the password in chat.
If the
user cancels the system dialog or it fails, stop and report the failure; do not silently
fall back to another privilege path or retry. This requests operating-system authorization
and does not bypass the client's sandbox or tool approval rules. AppleScript buffers output
until the command finishes; keep the execution session alive and do not start a duplicate
installation while waiting. Verify the result with `doctor` and `daemon status` afterward.

## Installation, Upgrades, and Rollback

```bash
bash "$BOOST_VPN_SCRIPT" plan-install
BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" install
# Upgrades use the same official download workflow.
BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" upgrade
# Set a version only when the user specifies or confirms the rollback version.
BOOST_VERSION=vX.Y.Z BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" install
```

Run `plan-install` first to review the operating system, architecture, version selection,
affected paths, and service startup options. Planning makes no network requests. For the
default version, it shows how the stable pointer is selected; the actual version is resolved
during installation.

Every macOS/Linux installation downloads the official installer from
`https://static.getboost.app/boostcli/install.sh`. The wrapper elevates privileges only after
the download is complete, nonempty, and passes Bash syntax validation. The official installer
then downloads the release archive and `SHA256SUMS`, validates the checksum, archive paths,
and release contents, and installs the release. Neither the skill nor the plugin bundles
installers or binaries. HTTPS protects the download source and transport; SHA256 verifies
file integrity and must not be described as an independent publisher signature.

The macOS/Linux wrapper supports arm64 and amd64; Linux uses systemd.
Archive availability for each architecture depends on what the official
website has published. Stop and report missing archives; do not substitute another architecture
or files from the repository's `bin/` directory. The wrapper always uses the official source
and does not accept alternative sources through `BOOST_BASE_URL` or `BOOST_LOCAL_*`.

Upgrades replace the system configuration and restart the service. Check the connection
status first and disconnect normally as part of the user-authorized upgrade. Back up any
custom configuration before proceeding. The wrapper passes through `BOOST_VERSION`,
`BOOST_NO_START`, and `BOOST_GROUP`; `BOOST_NO_START=1` prevents service startup after
installation. Group changes may require the user to log in to the operating system again.
After installation, run `doctor` and `daemon status`. An inactive service is expected when
`BOOST_NO_START` is set.

## QR Code Login

```bash
BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" login
```

Start login in a session that supports reading output continuously; do not wait for the
command to exit before displaying the QR code. The wrapper runs `boostcli login --png`,
filters out terminal QR codes, authorization links, and account details, and outputs only
the temporary PNG's absolute path and fixed status messages. As soon as
`QR code image saved to ...` appears, display that file and keep the same login process
running while the user scans the code and confirms authorization on their phone.

- In Codex, when local image display is supported, show the image inline with
  `![Boost login QR](/actual/absolute/path.png)`.
- In Claude Code, use the image display capabilities available in the current client.
  If the client cannot display local images to the user, open the PNG in an image viewer
  on the user's machine. In remote or headless environments, ask the user to run
  `boostcli login` in their own terminal. The model being able to read an image does not
  mean the user has seen it.
- Do not write one-time payloads, authorization URLs, or PNG contents to documents, logs,
  or commits. Do not echo these data.
- End the workflow when the user authorizes, cancels, or the QR code expires. The wrapper
  removes temporary files. Do not retry indefinitely after expiration; generate a new
  code only when the user requests another attempt.
- After success, check `status` and report account login and VPN connection status
  separately. Successful login does not imply a successful VPN connection. Do not assume
  login disconnects an existing connection either.

## Nodes and Connections

Before every connection or node switch, run `boostcli account --json` directly on the
resolved native CLI (the Bash wrapper does not forward `account`). Require a successful
response and use its `tier` to filter the current `nodes --json` list before applying
the user's country, node, or latency preferences:

| Account tier | Eligible nodes |
| --- | --- |
| `Ultimate` | All nodes in the current list, including `Ultimate` and `Premium` |
| `Premium` | Only nodes whose `tier` is `Premium` |
| `Free` | None; explain that a subscription in the Boost App is required before connecting |

Do not infer eligibility from a node being listed, a previous login, or the lowest
latency. If no eligible node matches the request, explain the limitation instead of
connecting to an ineligible node or silently changing the requested country. An explicit
node ID is subject to the same check. For `NOT_LOGGED_IN`, complete authorized login and
query `account` again; do not treat a missing login as `Free`. If account lookup fails,
the tier is missing or unrecognized, or the installed CLI lacks `account`, stop selection
and report that entitlement could not be verified. Do not guess a tier or probe access
by attempting connections. See [references/usage.md](references/usage.md) for account
output, subscription refresh timing, and `VIP_REQUIRED` handling.

When the agent's control channel may traverse the VPN being changed, ensure the user
has an independent local recovery path before connecting or switching nodes: provide
the exact `boostcli disconnect` command to run in their own terminal, using the resolved
CLI path if needed. Do not assume a later remote or approval-gated operation will remain
reachable after system routes change.

Do not report a Boost operation as failed or completed unless `boostcli` actually
started. If the shell, tool, or authorization layer fails first, report that execution-layer
failure separately. A failed status check does not establish the outcome of a prior operation.

```bash
bash "$BOOST_VPN_SCRIPT" nodes --json
bash "$BOOST_VPN_SCRIPT" connect 123   # Replace with a real positive integer node_id.
bash "$BOOST_VPN_SCRIPT" status --json
bash "$BOOST_VPN_SCRIPT" disconnect
BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" logout
```

Use a `node_id` from the eligible nodes in the current list, selected according to the
user's country, node, or performance preferences. Do not invent IDs. A `connecting` response from `connect`
only acknowledges the request. Keep checking `status` until it reports `connected` or an
error. If the wait times out, report that the connection is still in progress. Use `connect`
to switch nodes as well; it tears down the previous connection first.
Logout disconnects the VPN before clearing authorization.

Read [references/usage.md](references/usage.md) for the full command reference, JSON
structures, subscription errors, and platform service management when automating,
troubleshooting, or recovering services. Do not run `boostcli` without arguments for
automation, because that opens the interactive TUI.

## Diagnostics and Uninstallation

```bash
bash "$BOOST_VPN_SCRIPT" doctor
bash "$BOOST_VPN_SCRIPT" daemon status
bash "$BOOST_VPN_SCRIPT" daemon logs --lines 50
BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" uninstall
# Use only when the user explicitly requests removal of configuration and login state.
BOOST_VPN_CONFIRM=1 bash "$BOOST_VPN_SCRIPT" uninstall --purge
```

Uninstallation runs through `sudo boostcli uninstall`, preserving the CLI's safe disconnect
checks. Stop if disconnection fails; do not bypass these checks with the underlying script.
A normal uninstall preserves configuration and login state; `--purge` removes them.
If the CLI is broken, follow the recovery steps in the usage reference.

If downloading, verification, or installation fails, report the failing stage. Do not cycle
through alternative sources or architectures. Include only necessary, redacted excerpts
from diagnostic logs. Stop services normally through launchd or systemd. Do not use
`kill -9` or SIGTERM on `boostvpnd` or `leaf`; the tunnel engine needs a safe interrupt to
restore routes.
