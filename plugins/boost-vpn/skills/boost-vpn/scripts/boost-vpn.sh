#!/usr/bin/env bash
set -euo pipefail

CLI="${BOOST_VPN_CLI:-}"
UNINSTALLER="${BOOST_VPN_UNINSTALLER:-}"
DEFAULT_BASE_URL="https://static.getboost.app"
INSTALLER_URL="$DEFAULT_BASE_URL/boostcli/install.sh"

die() {
  echo "Error: $*" >&2
  exit 1
}

print_shell_quoted_command() {
  local value quoted
  printf 'command after confirmation: BOOST_VPN_CONFIRM=1'
  for value in "$@"; do
    printf -v quoted '%q' "$value"
    printf ' %s' "$quoted"
  done
  printf '\n'
}

detect_target() {
  local system machine os_prefix
  system="$(uname -s)"
  machine="$(uname -m)"
  case "$system" in
    Darwin) os_prefix=darwin ;;
    Linux) os_prefix=linux ;;
    *) die "Boost VPN supports macOS and Linux only (detected $system)" ;;
  esac
  case "$machine" in
    arm64|aarch64) printf '%s\n' "$os_prefix-arm64" ;;
    x86_64|amd64) printf '%s\n' "$os_prefix-amd64" ;;
    *) die "Unsupported $system architecture: $machine" ;;
  esac
}

configure_target() {
  local target="$1"
  case "$target" in
    darwin-*)
      PLATFORM=darwin
      [ -n "$CLI" ] || CLI=/usr/local/bin/boostcli
      [ -n "$UNINSTALLER" ] || UNINSTALLER=/usr/local/lib/boost/uninstall.sh
      ;;
    linux-*)
      PLATFORM=linux
      [ -n "$CLI" ] || CLI=/usr/bin/boostcli
      [ -n "$UNINSTALLER" ] || UNINSTALLER=/usr/lib/boost/uninstall.sh
      ;;
    *) die "Unsupported target: $target" ;;
  esac
}

print_install_plan() {
  local target="$1"
  configure_target "$target"
  echo "Boost VPN installation plan"
  echo "source: official"
  echo "installer_url: $INSTALLER_URL"
  echo "version: ${BOOST_VERSION:-stable/$target.txt (fallback: stable.txt)}"
  echo "target: $target"
  echo "base_url: $DEFAULT_BASE_URL"
  echo "start_service: $([ -z "${BOOST_NO_START:-}" ] && echo yes || echo no)"
  echo "socket_group: ${BOOST_GROUP:-boostvpn}"
  echo "configuration: replaced on install/upgrade; back up custom settings first"
  if [ "$PLATFORM" = linux ]; then
    echo "system changes: /usr/bin/boostcli, /usr/bin/boostvpnd, /usr/lib/boost, /etc/boostvpnd/config.toml"
    echo "service: boostvpnd.service"
  else
    echo "system changes: /usr/local/bin/boostcli, /usr/local/bin/boostvpnd, /usr/local/lib/boost, /Library/Preferences/boostvpnd.toml"
    echo "service: app.getboost.boostvpnd"
  fi
  echo "confirmation: required before execution"
}

require_confirmation() {
  local action="$1"
  shift
  TARGET="$(detect_target)"
  configure_target "$TARGET"
  if [ "${BOOST_VPN_CONFIRM:-0}" != "1" ]; then
    print_install_plan "$TARGET" 2>/dev/null || true
    print_shell_quoted_command "$0" "$action" "$@"
    die "Confirmation required for $action. Show the exact command and affected paths, then rerun with BOOST_VPN_CONFIRM=1."
  fi
}

run_install() (
  # A subshell keeps download cleanup separate from the interactive login traps.
  local download_dir installer
  download_dir="$(mktemp -d "${TMPDIR:-/tmp}/boost-vpn-install.XXXXXX")"
  trap 'rm -rf "$download_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  installer="$download_dir/install.sh"
  echo "Downloading official installer: $INSTALLER_URL"
  curl --proto '=https' --proto-redir '=https' -fsSL \
    --connect-timeout 15 --max-time 120 --retry 2 \
    -o "$installer" "$INSTALLER_URL" || die "Unable to download the official Boost installer"
  [ -s "$installer" ] || die "The official installer download is empty"
  bash -n "$installer" || die "The downloaded installer is not a valid shell script"
  # Clear local-package inputs even when the privilege helper preserves the caller's environment.
  # Release selection, SHA256 and archive validation belong to the official installer.
  run_privileged_install "$installer"
)

run_privileged_install() {
  local installer="$1" console_user invoking_user
  invoking_user="$(id -un)"
  if [ "$PLATFORM" = darwin ] && [ "$EUID" -ne 0 ] \
    && [ -z "${SSH_CONNECTION:-}${SSH_TTY:-}" ] \
    && command -v osascript >/dev/null 2>&1; then
    console_user="$(stat -f '%Su' /dev/console 2>/dev/null || true)"
    if [ "$console_user" = "$invoking_user" ]; then
      # Apple calls this a password dialog. `do shell script ... with administrator privileges`
      # uses Authorization Services and never exposes the password to this script or the chat.
      # Pass arguments as data and quote them in AppleScript for its /bin/sh interpreter.
      # Unlike sudo, Authorization Services does not set SUDO_USER: preserve the invoking
      # account so the official installer can add it to the VPN socket group.
      echo "Requesting macOS administrator authorization in the system password dialog..."
      if ! osascript - /usr/bin/env "SUDO_USER=$invoking_user" \
        "BOOST_BASE_URL=$DEFAULT_BASE_URL" "BOOST_VERSION=${BOOST_VERSION:-}" \
        "BOOST_NO_START=${BOOST_NO_START:-}" "BOOST_GROUP=${BOOST_GROUP:-}" \
        BOOST_LOCAL_ARCHIVE= BOOST_LOCAL_SUMS= /bin/bash "$installer" <<'APPLESCRIPT'
on run argv
  set commandText to ""
  repeat with argumentValue in argv
    set commandText to commandText & quoted form of (contents of argumentValue) & " "
  end repeat
  with timeout of 3600 seconds
    return do shell script commandText with administrator privileges without altering line endings
  end timeout
end run
APPLESCRIPT
      then
        die "macOS administrator authorization or installation failed"
      fi
      return 0
    fi
  fi
  # SSH/headless sessions and Linux keep the terminal sudo path. `sudo` is deliberately
  # not run for the whole wrapper, so read-only operations never request elevation.
  sudo env BOOST_BASE_URL="$DEFAULT_BASE_URL" \
    BOOST_VERSION="${BOOST_VERSION:-}" BOOST_NO_START="${BOOST_NO_START:-}" \
    BOOST_GROUP="${BOOST_GROUP:-}" BOOST_LOCAL_ARCHIVE= BOOST_LOCAL_SUMS= \
    bash "$installer"
}

run_cli() {
  [ -x "$CLI" ] || die "Boost VPN CLI is not installed: $CLI"
  "$CLI" "$@"
}

cleanup_login() {
  local status=$?
  trap - EXIT INT TERM
  if [ -n "${LOGIN_CHILD_PID:-}" ]; then
    terminate_login_process "$LOGIN_CHILD_PID"
  fi
  if [ -n "${LOGIN_FILTER_PID:-}" ]; then
    terminate_login_process "$LOGIN_FILTER_PID"
  fi
  if [ -n "${LOGIN_FIFO:-}" ]; then
    rm -f "$LOGIN_FIFO"
  fi
  if [ -n "${LOGIN_TMP_DIR:-}" ]; then
    rm -rf "$LOGIN_TMP_DIR"
  fi
  exit "$status"
}

login_process_alive() {
  local state
  kill -0 "$1" 2>/dev/null || return 1
  state="$(ps -o stat= -p "$1" 2>/dev/null || true)"
  [ -n "$state" ] || return 1
  case "$state" in
    Z*) return 1 ;;
  esac
  return 0
}

terminate_login_process() {
  local pid="$1" attempts=0
  [ -n "$pid" ] || return 0
  if login_process_alive "$pid"; then
    kill -TERM "$pid" 2>/dev/null || true
    while login_process_alive "$pid" && [ "$attempts" -lt 10 ]; do
      sleep 0.1 || true
      attempts=$((attempts + 1))
    done
    if login_process_alive "$pid"; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
  wait "$pid" 2>/dev/null || true
}

wait_for_login_process_exit() {
  local pid="$1" attempts=0
  while login_process_alive "$pid" && [ "$attempts" -lt 50 ]; do
    sleep 0.1 || true
    attempts=$((attempts + 1))
  done
  ! login_process_alive "$pid"
}

handle_login_signal() {
  LOGIN_SIGNAL_STATUS="$1"
  if [ -n "${LOGIN_CHILD_PID:-}" ]; then
    kill -TERM "$LOGIN_CHILD_PID" 2>/dev/null || true
  fi
  if [ -n "${LOGIN_FILTER_PID:-}" ]; then
    kill -TERM "$LOGIN_FILTER_PID" 2>/dev/null || true
  fi
}

filter_login_output() {
  local line
  while IFS= read -r line; do
    case "$line" in
      "QR code image saved to /"*) printf '%s\n' "$line" ;;
      "Scanned QR code"|"Scanned, confirm on your phone") printf '%s\n' "$line" ;;
    esac
  done
}

login_qr_expired() {
  [ -f "$LOGIN_STDERR_FILE" ] || return 1
  grep -Eq '^(Error: QR code expired|Error: QR code sign-in timed out; run boostcli login again)$' \
    "$LOGIN_STDERR_FILE"
}

run_login() {
  local tmp_root help_output cli_status filter_status
  [ -x "$CLI" ] || die "Boost VPN CLI is not installed: $CLI"
  if ! help_output="$("$CLI" login --help 2>&1)" || \
    ! grep -Eq '(^|[^[:alnum:]_-])--png([^[:alnum:]_-]|$)' <<<"$help_output"; then
    die 'Boost VPN CLI does not support PNG login output; install or update boostcli with login --png support, then retry.'
  fi
  tmp_root="${BOOST_VPN_TMPDIR:-${TMPDIR:-/tmp}}"
  mkdir -p "$tmp_root"
  tmp_root="$(cd "$tmp_root" && pwd -P)"
  LOGIN_TMP_DIR="$(mktemp -d "${tmp_root%/}/boost-vpn-login.XXXXXX")"
  LOGIN_FIFO="$LOGIN_TMP_DIR/stdout"
  LOGIN_STDERR_FILE="$LOGIN_TMP_DIR/stderr"
  LOGIN_SIGNAL_STATUS=0
  mkfifo "$LOGIN_FIFO"
  trap cleanup_login EXIT
  trap 'handle_login_signal 130' INT
  trap 'handle_login_signal 143' TERM
  "$CLI" login --png "$LOGIN_TMP_DIR/boost-login.png" >"$LOGIN_FIFO" 2>"$LOGIN_STDERR_FILE" &
  LOGIN_CHILD_PID=$!
  filter_login_output <"$LOGIN_FIFO" &
  LOGIN_FILTER_PID=$!

  if wait "$LOGIN_FILTER_PID"; then
    filter_status=$?
  else
    filter_status=$?
  fi
  LOGIN_FILTER_PID=""
  if wait "$LOGIN_CHILD_PID"; then
    cli_status=$?
  else
    cli_status=$?
  fi
  LOGIN_CHILD_PID=""
  if [ "$LOGIN_SIGNAL_STATUS" -ne 0 ]; then
    return "$LOGIN_SIGNAL_STATUS"
  fi
  if [ "$filter_status" -ne 0 ]; then
    printf 'Boost login failed: login output filter exited unexpectedly\n' >&2
    return 1
  fi
  if [ "$LOGIN_SIGNAL_STATUS" -ne 0 ]; then
    return "$LOGIN_SIGNAL_STATUS"
  fi
  if [ "$cli_status" -ne 0 ]; then
    if login_qr_expired; then
      printf 'Boost login QR expired\n'
    fi
    printf 'Boost login failed (exit code %d)\n' "$cli_status" >&2
  else
    printf 'Boost login completed\n'
  fi
  return "$cli_status"
}

run_doctor() {
  local target
  target="$(detect_target)"
  echo "Boost VPN doctor"
  echo "target: $target"
  if [ -x "$CLI" ]; then
    echo "cli: installed ($CLI)"
    "$CLI" version
  else
    echo "cli: not installed ($CLI)"
  fi
  if [ -x "$UNINSTALLER" ]; then
    echo "uninstaller: installed ($UNINSTALLER)"
  else
    echo "uninstaller: not installed ($UNINSTALLER)"
  fi
}

command_name="${1:-plan-install}"
shift || true
TARGET="$(detect_target)"
configure_target "$TARGET"
case "$command_name" in
  plan-install)
    [ "$#" -eq 0 ] || die "plan-install does not accept arguments"
    print_install_plan "$TARGET"
    ;;
  install|upgrade)
    [ "$#" -eq 0 ] || die "$command_name does not accept arguments"
    require_confirmation "$command_name"
    run_install
    ;;
  status|version|nodes|watch)
    run_cli "$command_name" "$@"
    ;;
  daemon)
    [ "$#" -gt 0 ] || die "daemon requires a subcommand"
    case "$1" in
      status|logs)
        run_cli daemon "$@"
        ;;
      *)
        require_confirmation "daemon" "$@"
        run_cli daemon "$@"
        ;;
    esac
    ;;
  login)
    [ "$#" -eq 0 ] || die "login does not accept arguments"
    require_confirmation "$command_name"
    run_login
    ;;
  logout)
    require_confirmation "$command_name" "$@"
    run_cli logout "$@"
    ;;
  connect|disconnect)
    run_cli "$command_name" "$@"
    ;;
  doctor)
    [ "$#" -eq 0 ] || die "doctor does not accept arguments"
    run_doctor
    ;;
  uninstall)
    purge=0
    case "${1:-}" in
      "") ;;
      "--purge") purge=1; shift ;;
      *) die "uninstall accepts only --purge" ;;
    esac
    [ "$#" -eq 0 ] || die "uninstall accepts only --purge"
    if [ "$purge" -eq 1 ]; then
      require_confirmation "uninstall" "--purge"
    else
      require_confirmation "uninstall"
    fi
    [ -x "$CLI" ] || die "Boost VPN CLI is not installed: $CLI; use the documented service-stop recovery before running a local uninstaller"
    if [ "$purge" -eq 1 ]; then
      sudo "$CLI" uninstall --purge
    else
      sudo "$CLI" uninstall
    fi
    ;;
  *)
    die "Unknown operation: $command_name"
    ;;
esac
