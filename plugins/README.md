# Boost VPN Codex Plugin

For the recommended release ZIP workflow and a prompt that asks Codex to install the
downloaded package for you, see the [repository README](../README.md#recommended-download-the-release-zip-and-let-codex-install-it).

`boost-vpn/` is a Codex plugin with `.codex-plugin/plugin.json` as its manifest.
It bundles the same skill as `skills/boost-vpn/` and supports installation and everyday
use on macOS, Linux, and Windows.
The skill automatically selects the native workflow for the detected OS and architecture:
Bash on macOS/Linux, PowerShell and `boostcli.exe` on Windows.
On macOS local graphical sessions, installation can show the system password dialog through
Authorization Services; SSH/headless sessions retain the terminal `sudo` flow.

```text
plugins/boost-vpn/
├── .codex-plugin/plugin.json
├── assets/boost-vpn.png
├── skills/boost-vpn/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   ├── references/usage.md
│   ├── references/windows.md
│   └── scripts/boost-vpn.sh
└── scripts/
    └── boost-vpn.sh                 # Preserves the original invocation path
```

## Add to Codex

The repository's `.agents/plugins/marketplace.json` defines a marketplace named `personal`
with an entry pointing to `./plugins/boost-vpn`. This is a repository marketplace, not an
implicit marketplace in the user's home directory. Installation requires a local
Codex CLI that supports `codex plugin` (check with `codex plugin --help`). Before adding
the source, run `codex plugin marketplace list --json`. If `personal` already exists,
verify that it points to the intended package or repository; reuse a matching source and resolve a conflicting
source before installing.

### Recommended: Install the Release ZIP with Codex

1. [Download boost-vpn-codex-plugin.zip (v1.0.0)](https://github.com/Boost-vpn/boostvpn-cli/releases/download/v1.0.0/boost-vpn-codex-plugin.zip).
2. Start a local Codex task and provide the full path to the downloaded ZIP.
3. Ask Codex to extract the package and complete installation using its included README.
   A ready-to-copy prompt is available in the [repository README](../README.md#recommended-download-the-release-zip-and-let-codex-install-it).

The ZIP extracts to `boost-vpn-package/`, which contains the marketplace configuration
and the complete plugin. Codex should extract it to a persistent local directory and run
the following commands from the **extracted package root** containing
`.agents/plugins/marketplace.json`:

```bash
codex plugin marketplace add .
codex plugin add boost-vpn@personal
codex plugin list --marketplace personal --json
```

Keep the extracted package in place as the local marketplace source, including the
hidden `.agents/` and `.codex-plugin/` directories. This workflow uses the downloaded
package and does not require cloning the Git repository.

### Alternative: Install from GitHub

With Git installed and access to GitHub, install directly from the repository:

```bash
codex plugin marketplace add https://github.com/Boost-vpn/boostvpn-cli.git
codex plugin add boost-vpn@personal
codex plugin list --marketplace personal --json
```

For an existing local clone, run `codex plugin marketplace add .` from the repository
root instead of the GitHub registration command above, then install the plugin with
`codex plugin add boost-vpn@personal`. Start a new session after installation and ask
Codex to check your Boost VPN installation and connection status.

Codex can also use the standalone skill; installing both forms is usually unnecessary.
For Claude Code, follow the
[shared skill installation instructions](../skills/README.md). The plugin manifest in this
directory is for Codex only.

## Official Downloads

On macOS/Linux, installation and upgrades fetch the installer from
`https://static.getboost.app/boostcli/install.sh`. A failed download, empty response, or
Bash syntax error prevents privileged execution. The installer selects a version through
the target platform's stable pointer, downloads the release archive and SHA256 checksums,
validates the archive, and installs it on the system.

On Windows x64, the plugin uses native PowerShell:

```powershell
irm https://static.getboost.app/boostcli/install.ps1 | iex
```

The Windows installer checks the archive checksum and daemon Authenticode signature,
then requests UAC elevation. It requires Windows 10 1809 / Server 2019 or newer.
Full removal uses `boostcli uninstall --purge` in Administrator PowerShell, removing
configuration, login state, and logs. Use `boostcli uninstall` to preserve local data.
Windows operations do not require Bash or WSL; see the bundled
[Windows workflow](boost-vpn/skills/boost-vpn/references/windows.md).

Set `BOOST_VERSION` to select a specific version; the default is the official stable release.
The selected version must have a published archive for the target architecture.

The plugin does not include `assets/releases/`, a copy of the installer, or a bundle
validator. Download failures at runtime are reported directly. HTTPS protects the official
installer download; release archive checksums are not independent digital signatures.

## Maintenance and Distribution

Publish the repository with `.agents/plugins/marketplace.json` and the complete
`plugins/boost-vpn/` directory, preserving their relative paths. A local directory or
extracted archive with the same layout can be registered with
`codex plugin marketplace add .` from its root, followed by
`codex plugin add boost-vpn@personal`.

The plugin includes actual copies of the shared skill. After editing
`skills/boost-vpn/`, copy the changed files and apply any removals to
`plugins/boost-vpn/skills/boost-vpn/`. From the repository root on macOS/Linux, check
consistency before publishing:

```bash
diff -qr skills/boost-vpn plugins/boost-vpn/skills/boost-vpn
```

Keep the root `skills/` directory and README files when distributing both installation
options. The repository contains no automated packaging target or skill-sync script.
