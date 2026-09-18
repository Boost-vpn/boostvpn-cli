# Boost VPN Skill (Claude Code / Codex)

For installation instructions and prompts you can send directly to Codex or
Claude Code, see the [repository README](../README.md).

`boost-vpn/` is a standalone Agent Skill covering installation, QR login, node selection,
connection, disconnection, diagnostics, upgrades, rollback, and uninstallation. It supports
macOS, Linux with systemd, and Windows. Release packages are downloaded from the official
Boost website; no installer packages or fixed versions are bundled.
The skill detects the target OS and architecture before choosing commands: macOS/Linux
use the bundled Bash helper; Windows uses native PowerShell and `boostcli.exe`.

## Install the Skill

From the repository root, run the commands for your client. If the destination directory
already exists, back it up or inspect it before overwriting it.

macOS/Linux:

```bash
# Claude Code: personal skill
mkdir -p "$HOME/.claude/skills"
cp -R skills/boost-vpn "$HOME/.claude/skills/"

# Codex: personal skill
mkdir -p "$HOME/.agents/skills"
cp -R skills/boost-vpn "$HOME/.agents/skills/"
```

Windows (PowerShell; choose the destination for your client):

```powershell
# Claude Code: personal skill
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item -Recurse skills/boost-vpn "$env:USERPROFILE\.claude\skills\"

# Codex: personal skill
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
Copy-Item -Recurse skills/boost-vpn "$env:USERPROFILE\.agents\skills\"
```

For a project installation, copy the same directory into the target project's
`.claude/skills/` (Claude Code) or `.agents/skills/` (Codex). The repository's root `skills/`
directory holds the distribution source; do not assume clients discover it automatically.
Start a new session after installation. Use `/boost-vpn` in Claude Code or `$boost-vpn`
in Codex, or simply ask "Check Boost VPN status" or "Install and log in to Boost VPN".
`agents/openai.yaml` provides Codex display metadata; Claude Code uses the same `SKILL.md`.

Installation and upgrades run the official installer and request administrator privileges.
On macOS, a local graphical session uses the system password dialog for installation
and upgrades; SSH/headless sessions use terminal `sudo`. Passwords stay in the system
authentication interface, and canceling authorization stops the operation.
A status request does not trigger installation. QR login requires the user to authorize
on their phone and does not connect the VPN automatically.
On Windows, Boost VPN installation/upgrades use
`irm https://static.getboost.app/boostcli/install.ps1 | iex`; full removal uses
`boostcli uninstall --purge` in Administrator PowerShell and removes configuration,
login state, and logs. Windows currently supports x64 only. See the skill's
[Windows workflow](boost-vpn/references/windows.md) for all Windows operations.

Directory conventions follow [Claude Code Skills](https://code.claude.com/docs/en/skills)
and [Codex Skills](https://developers.openai.com/codex/skills/).

## Maintenance

After editing `skills/boost-vpn/`, copy the changed files into
`plugins/boost-vpn/skills/boost-vpn/` as well, including any file removals. From the
repository root on macOS/Linux, check that the two directories match:

```bash
diff -qr skills/boost-vpn plugins/boost-vpn/skills/boost-vpn
```

The plugin contains actual file copies rather than symlinks to locations outside the
repository, so `plugins/boost-vpn/` remains usable when copied on its own. Do not maintain
the two skill copies independently.
