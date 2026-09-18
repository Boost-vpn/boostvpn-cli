#!/usr/bin/env bash
set -euo pipefail
# Keep the existing plugin entrypoint usable after moving helpers into the Skill.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/../skills/boost-vpn/scripts/boost-vpn.sh" "$@"
