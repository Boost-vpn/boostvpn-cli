# Boost VPN Skills & Codex Plugin

Use Codex or Claude Code to install, log in to, and manage [Boost VPN](https://getboost.app).
Check status, sign in with a QR code, select nodes, connect or disconnect, view logs,
upgrade, and uninstall.

This repository provides two installation options. Choose the one that fits your client:

| Installation option | Supported clients | Repository directory |
| --- | --- | --- |
| **Codex plugin (recommended for Codex users)** | Codex desktop / CLI with plugin support | [`plugins/boost-vpn/`](plugins/boost-vpn/) |
| **Standalone skill** | Codex, Claude Code | [`skills/boost-vpn/`](skills/boost-vpn/) |

Both options contain the same Boost VPN skill, so installing both is usually unnecessary.
Installing a skill or plugin adds capabilities to your AI assistant. The Boost VPN client
is downloaded from the official website when you ask the assistant to install it.

## Install the Codex Plugin

### Recommended: Download the Release ZIP and Let Codex Install It

1. [Download boost-vpn-codex-plugin.zip (v1.0.0)](https://github.com/Boost-vpn/boostvpn-cli/releases/download/v1.0.0/boost-vpn-codex-plugin.zip) and save it on your computer.
2. Start a new local task in Codex and give it the full path to the downloaded ZIP.
3. Send the prompt below, replacing the example path with your file's actual path.
   Codex will extract the package, register its marketplace, and install the plugin.

```text
Please install the Boost VPN Codex plugin from this downloaded ZIP:
/absolute/path/to/boost-vpn-codex-plugin.zip

Extract it to a persistent local directory and read the included README.md.
The package root is boost-vpn-package, containing .agents/plugins/marketplace.json.
Preserve the complete package, including its hidden directories.

Check codex plugin --help and codex plugin marketplace list --json.
Register the extracted package root as a local marketplace, then install
boost-vpn@personal. If personal already points to this extracted package, reuse it.
If it points to another source, report the conflict before changing it.

Verify installation with codex plugin list --marketplace personal --json.
Tell me where the package was saved and how to use the plugin in a new session.
```

For example, the ZIP path might be `/Users/you/Downloads/boost-vpn-codex-plugin.zip`
on macOS, `/home/you/Downloads/boost-vpn-codex-plugin.zip` on Linux, or
`C:\Users\you\Downloads\boost-vpn-codex-plugin.zip` on Windows.

Keep the extracted `boost-vpn-package/` directory in place after installation: Codex uses
it as the local marketplace source. The package includes the `.agents/` and
`.codex-plugin/` hidden directories required for installation.

Codex needs access to the downloaded file and permission to run local commands. A local
Codex CLI version that supports `codex plugin` must be available. If you see
`codex: command not found` or the `plugin` subcommand is unavailable, install or update
Codex CLI, or use the standalone skill instructions below. The Codex IDE extension can
use the standalone skill.

### Alternative: Ask Codex to Install from GitHub

To install from the repository instead of a release ZIP, send this prompt in Codex.
This method also requires Git and access to GitHub.

```text
Please install the Boost VPN Codex plugin from this repository:
https://github.com/Boost-vpn/boostvpn-cli

The marketplace configuration is .agents/plugins/marketplace.json.
The marketplace name is personal, and the plugin name is boost-vpn.

First, check codex plugin --help and codex plugin marketplace list --json.
If personal has not been registered, run:
codex plugin marketplace add https://github.com/Boost-vpn/boostvpn-cli.git

After confirming that personal points to this repository, run:
codex plugin add boost-vpn@personal
codex plugin list --marketplace personal --json

If personal already points to this repository, reuse the existing configuration.
If it points to another source, report the conflict.
Verify that the plugin is installed and explain how to use it in a new session.
```

### Alternative: Install from GitHub Manually

You can also run the following commands in a terminal. First, check existing sources
with `codex plugin marketplace list --json`. If a marketplace named `personal` already
exists, confirm that it points to this repository before continuing.

```bash
codex plugin marketplace add https://github.com/Boost-vpn/boostvpn-cli.git
codex plugin add boost-vpn@personal
codex plugin list --marketplace personal --json
```

If you already have a local clone, register it from the **repository root** instead of
using the GitHub registration command above:

```bash
codex plugin marketplace add .
```

`personal` is the name defined in this repository's
[marketplace configuration](.agents/plugins/marketplace.json). It is not a GitHub username.
Cloning the repository or registering its marketplace does not install the plugin;
you still need to run `codex plugin add boost-vpn@personal`.

After installation, start a new Codex session and ask:
"Use Boost VPN to check my installation and connection status."
See the [plugin documentation](plugins/README.md) for more details.

## Install the Standalone Skill

### Ask Your AI Assistant to Install It

In Codex, send:

```text
Please use $skill-installer to install skills/boost-vpn from the main branch of
https://github.com/Boost-vpn/boostvpn-cli into my user-level skills directory.
Include the entire directory: SKILL.md, scripts, references, and agents.
```

In Claude Code, send:

```text
Please clone https://github.com/Boost-vpn/boostvpn-cli and install the entire
skills/boost-vpn directory into my personal ~/.claude/skills/boost-vpn directory.
On Windows, use .claude/skills/boost-vpn under my user profile directory.
If the destination already exists, inspect its contents before deciding how to update it.
After installation, verify that SKILL.md, scripts, and references are present.
```

### Install Manually

Clone the repository and enter its root directory:

```bash
git clone https://github.com/Boost-vpn/boostvpn-cli.git
cd boostvpn-cli
```

Choose the installation location for your client. A user-level installation is available
across your local projects; a project-level installation applies to the target project.

| Client | User-level directory | Project-level directory |
| --- | --- | --- |
| Codex | `~/.agents/skills/boost-vpn/` | `<project>/.agents/skills/boost-vpn/` |
| Claude Code | `~/.claude/skills/boost-vpn/` | `<project>/.claude/skills/boost-vpn/` |

On macOS / Linux, run the commands for your client. Inspect or back up an existing
destination directory before copying.

```bash
# Codex
mkdir -p "$HOME/.agents/skills"
cp -R skills/boost-vpn "$HOME/.agents/skills/"

# Claude Code
mkdir -p "$HOME/.claude/skills"
cp -R skills/boost-vpn "$HOME/.claude/skills/"
```

In Windows PowerShell, run the commands for your client:

```powershell
# Codex
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
Copy-Item -Recurse skills/boost-vpn "$env:USERPROFILE\.agents\skills\"

# Claude Code
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item -Recurse skills/boost-vpn "$env:USERPROFILE\.claude\skills\"
```

For a project-level installation, copy the entire `skills/boost-vpn/` directory to the
appropriate location in the table above. Include `scripts/`, `references/`, and `agents/`
along with `SKILL.md`. The repository's root `skills/` directory holds the distribution
source; install the skill in a location your client recognizes so it can discover it.

To verify installation, start a new session and enter `$boost-vpn` in Codex or
`/boost-vpn` in Claude Code, or simply ask "Check Boost VPN status."
If the new skill does not appear, restart your client and try again.
See the [skill documentation](skills/README.md) for more details.

## Usage Examples

After installation, describe what you want in natural language:

```text
Check whether Boost VPN is installed and show the current connection status.
Install Boost VPN and show the login QR code.
List the Japan nodes available with my subscription and connect to the lowest-latency one.
Disconnect Boost VPN.
Show the Boost VPN service status and the latest 50 log lines.
Upgrade Boost VPN to the official stable release.
```

QR login requires you to confirm authorization on your phone. After signing in, you can
ask the assistant to connect to a node. Installing or upgrading the VPN client may require
administrator authorization from your operating system.

## Supported Platforms

| Operating system | Architecture | Workflow |
| --- | --- | --- |
| macOS | Apple Silicon / Intel (arm64 / amd64) | Bash + official installer |
| Linux | arm64 / amd64; requires systemd | Bash + official installer |
| Windows | x64; Windows 10 1809 / Server 2019 or later | Native PowerShell + `boostcli.exe` |

The skill detects the target operating system and architecture automatically. Windows uses
a native workflow and requires neither Bash nor WSL. Windows ARM64 / x86 are currently
unsupported. Available versions and architectures depend on the official release packages.

## Repository Structure and References

```text
.
├── README.md
├── .agents/plugins/marketplace.json     # Codex marketplace entry point
├── skills/
│   ├── README.md
│   └── boost-vpn/                      # Standalone skill for Codex / Claude Code
└── plugins/
    ├── README.md
    └── boost-vpn/
        ├── .codex-plugin/plugin.json   # Codex plugin manifest
        ├── assets/
        ├── scripts/
        └── skills/boost-vpn/           # The same skill, bundled with the plugin
```

- [Skill installation and maintenance](skills/README.md)
- [Codex plugin installation and distribution](plugins/README.md)
- [Boost VPN command reference](skills/boost-vpn/references/usage.md)
- [Windows workflow](skills/boost-vpn/references/windows.md)
- [Official Codex Skills documentation](https://developers.openai.com/codex/skills/)
- [Official Codex Plugins documentation](https://developers.openai.com/codex/plugins/)
- [Official Claude Code Skills documentation](https://code.claude.com/docs/en/skills)
