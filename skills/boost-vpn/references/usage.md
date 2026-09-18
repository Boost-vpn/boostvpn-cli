# boostcli Usage Reference

Native CLI commands and JSON formats below apply to macOS, Linux, and Windows.
For Windows installation, login, executable discovery, diagnostics, services, and removal,
read [windows.md](windows.md). All Bash wrapper and Unix path/service examples in this
reference apply only to macOS/Linux.

On macOS, the local graphical installation path may show the system **password dialog**
through AppleScript `do shell script … with administrator privileges` (Authorization
Services). SSH/headless sessions use `sudo` in the terminal. A canceled authorization
stops the operation.

## Commands and Output

The wrapper defaults to `/usr/local/bin/boostcli` on macOS and `/usr/bin/boostcli` on Linux.
If the user explicitly uses another installation path, set `BOOST_VPN_CLI=/absolute/path/to/boostcli`.
Check `boostcli --version` or the relevant subcommand's `--help` to verify the installed
version's capabilities; the official release may differ from the repository.
`boostcli --version` returns plain text, not JSON. Invoke it directly on the resolved CLI.

| Native command | Purpose |
| --- | --- |
| `boostcli --version` | Local version as plain text, not JSON; does not require the daemon |
| `boostcli account --json` | Account information and membership tier; requires login and a reachable daemon |
| `boostcli status --json` | Current connection status; does not require login |
| `boostcli nodes --json` | Live node list; requires login |
| `boostcli connect <node-id> --json` | Request a connection or switch; the ID must be a positive integer from the node list |
| `boostcli disconnect --json` | Disconnect the tunnel normally |
| `boostcli logout --json` | Disconnect before logging out |
| `boostcli daemon status --json` | Daemon version, PID, child processes, and related details |
| `boostcli daemon logs --lines 50 --json` | Recent logs; requires a reachable daemon |
| `boostcli watch --event state_changed --event error --json` | Continuous event stream; interrupt the client when finished |

On macOS/Linux the operational subcommands are also available through the wrapper with
the same names except `account`; invoke `account --json` and `--version` directly on the
resolved native CLI and use the wrapper's PNG workflow for login.
On Windows use the native CLI
and the PNG workflow in [windows.md](windows.md). `daemon status` and `daemon logs` are
diagnostic commands; the current CLI has no `daemon start/stop/restart` commands.
Use the platform commands below for service management rather than inventing CLI subcommands.

For ordinary commands, `--json` outputs one object. Errors use
`{"error":{"code":"...","message":"..."}}` and a nonzero exit code. Preserve the exit
code before parsing JSON; do not let a successful downstream pipeline hide a CLI failure.
`watch` and native `login --json` output line-delimited NDJSON; read it as it arrives
instead of waiting for the entire stream to finish.

The node list uses `countries[].nodes[]`, with fields including `node_id`, `name`, `tier`,
`latency`, and `protocol`. `latency` is a string such as `42ms` or `—`; `—` does not mean zero.
An empty list is `{"countries":[]}`. Stop connection attempts when no candidate nodes exist.
Use `state` as the authoritative status; fields such as `node`, `since`, and `last_error`
may be absent. The current engine uses Trojan. Unsupported protocols fail explicitly;
do not claim they are supported.

## Account and Node Eligibility

`boostcli account --json` returns `user`, `tier` (`Free`, `Premium`, or `Ultimate`),
and optional `expires`. Use `tier` as the entitlement decision; do not infer membership
from `user`, a missing expiry, or a locally parsed expiry date. For node selection,
report only the necessary tier information rather than repeating account identifiers.

Before connecting or switching, query the account and filter nodes according to the
[membership policy in SKILL.md](../SKILL.md#nodes-and-connections): `Ultimate` permits
all listed nodes, `Premium` permits only `Premium` nodes, and `Free` must subscribe first.
Rank by country and latency only within the eligible set. Listing a node does not grant
permission to connect to it. Unknown tiers or unsuccessful account queries do not grant
access; distinguish login, service-access, and execution-layer failures.

Account information comes from the daemon's cached user information, normally refreshed
every 60 seconds. After the user subscribes or upgrades, allow a short bounded wait and
re-query `account --json` before selecting nodes. Do not invent an `account --refresh`
flag, restart the service to force a refresh, or assume payment has already changed the
reported tier. If it remains unchanged, report that the entitlement is not yet reflected.
If the installed CLI does not support `account`, explain that a compatible update is
needed to verify eligibility; do not perform an unrequested upgrade.

The daemon remains authoritative at connection time. If it returns `VIP_REQUIRED`,
re-check the account and explain the subscription or upgrade requirement. Do not cycle
through disallowed nodes to bypass it; an earlier account check cannot override a denial.

## Common Failures

| Error code | Next step |
| --- | --- |
| `NOT_LOGGED_IN` / `SESSION_EXPIRED` | Log in again with the user's authorization |
| `AUTH_FAILED` | The QR code expired or authorization failed; stop this attempt and retry only at the user's request |
| `VIP_REQUIRED` | Re-check `account --json`; direct the user to subscribe or upgrade in the Boost App at https://getboost.app; do not retry disallowed nodes |
| `NODE_FULL` | Select another available node according to the user's preferences |
| `BUSY` | A connection or disconnection is in progress; wait for a state change without issuing duplicate concurrent requests |
| `NOT_CONNECTED` | Already disconnected; report the actual state |
| `DAEMON_UNREACHABLE` | First distinguish an execution-identity or IPC-access mismatch from a stopped service; do not change permissions or services without authorization |
| `PROCESS_FAILED` / `NETWORK` / `API_ERROR` | Review recent errors and logs, and report the specific failing stage |

The node list shows subscriber nodes only. Switching protocols cannot bypass subscription
tier restrictions. Neither the CLI nor the website provides subscription checkout.

## macOS/Linux System Paths and Services

| Item | macOS | Linux (systemd) |
| --- | --- | --- |
| CLI / daemon | `/usr/local/bin/boostcli`, `/usr/local/bin/boostvpnd` | `/usr/bin/boostcli`, `/usr/bin/boostvpnd` |
| Engine and uninstall script directory | `/usr/local/lib/boost` | `/usr/lib/boost` |
| Configuration | `/Library/Preferences/boostvpnd.toml` | `/etc/boostvpnd/config.toml` |
| Account state | `/Library/Application Support/Boost` | `/var/lib/boostvpnd` |
| Service | `app.getboost.boostvpnd` | `boostvpnd.service` |
| Socket | `/var/run/boostvpnd.sock` | `/run/boostvpnd.sock` |

Stop, start, or restart services only when the user has authorized service maintenance;
these operations interrupt the current VPN connection.

```bash
# macOS: inspect; stop; start after bootout; restart an already loaded service.
sudo launchctl print system/app.getboost.boostvpnd
sudo launchctl bootout system /Library/LaunchDaemons/app.getboost.boostvpnd.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/app.getboost.boostvpnd.plist
sudo launchctl kickstart -k system/app.getboost.boostvpnd

# Linux: inspect, view logs, stop, start, restart.
systemctl status boostvpnd.service --no-pager
sudo journalctl -u boostvpnd.service -n 50 --no-pager
sudo systemctl stop boostvpnd.service
sudo systemctl start boostvpnd.service
sudo systemctl restart boostvpnd.service
```

When the daemon is unreachable, `daemon logs` cannot work either. On macOS, inspect
`/var/log/boostvpnd.log` and `/var/log/boostvpnd/`; on Linux, use journald.
For socket permission issues, check group membership and whether a new login is needed
before making changes. Do not make the socket writable by everyone.

## macOS/Linux Uninstall Recovery When the CLI Is Unavailable

Prefer repairing the CLI and then running `sudo boostcli uninstall`. If directly invoking
the local uninstall script is necessary, first confirm that the VPN is disconnected or
safely stop the service through the system service manager, and confirm that the tunnel
engine has exited. Do not bypass checks when disconnection returns `BUSY` or another failure.

- macOS: `sudo bash /usr/local/lib/boost/uninstall.sh`
- Linux: `sudo bash /usr/lib/boost/uninstall.sh`

By default, configuration, login state, and any data the platform explicitly retains are
preserved. Add `--purge` only when the user explicitly authorizes their removal.
The official website does not publish the uninstall script separately; it is installed
locally as part of the release package.
