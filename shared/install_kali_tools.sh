#!/usr/bin/env bash
# install-kali-tools.sh
# Idempotent installer for common Kali tools.
# Usage:
#   sudo ./install-kali-tools.sh             # install default list
#   ./install-kali-tools.sh --dry-run        # show what would be installed
#   ./install-kali-tools.sh --extra "burpsuite gobuster"
#   ./install-kali-tools.sh --packages-file /path/to/list.txt
#
# Notes:
# - Designed for Debian-based systems (Kali). Uses apt-get.
# - Will re-run itself via sudo if not started as root.
# - Cleans apt lists at the end to reduce image size.
# - Writes /tmp/kali_install_report.txt (or $RESULT_LOG if set)

set -euo pipefail
IFS=$'\n\t'

DEFAULT_PACKAGES=(
  openssh-server
  vim
  htop
  nmap
  netcat-openbsd
  tcpdump
  enum4linux
  nikto
  sqlmap
  john
  hydra
  metasploit-framework
)

RESULT_LOG=${RESULT_LOG:-/tmp/kali_install_report.txt}
DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y" #--no-install-recommends"

# Helpers
log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

print_usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --dry-run                Show what would be installed and exit
  --extra "pkg1 pkg2"      Add extra apt packages to install
  --packages-file PATH     Read additional package names (one per line)
  --help                   Show this help and exit

Examples:
  sudo $0
  $0 --extra "burpsuite gobuster"
  $0 --packages-file ./my-pkgs.txt
USAGE
}

# Parse args
EXTRA_PACKAGES=()
PACKAGES_FILE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift;;
    --extra)
      shift
      if [[ $# -eq 0 ]]; then err "--extra requires an argument"; exit 2; fi
      # split on spaces
      read -r -a tmp <<< "$1"
      EXTRA_PACKAGES+=("${tmp[@]}")
      shift
      ;;
    --packages-file)
      shift
      if [[ $# -eq 0 ]]; then err "--packages-file requires a path"; exit 2; fi
      PACKAGES_FILE="$1"
      shift
      ;;
    -h|--help) print_usage; exit 0;;
    *) err "Unknown option: $1"; print_usage; exit 2;;
  esac
done

# Read packages from file if provided
if [[ -n "$PACKAGES_FILE" ]]; then
  if [[ ! -f "$PACKAGES_FILE" ]]; then
    err "Packages file not found: $PACKAGES_FILE"; exit 2
  fi
  while IFS= read -r line; do
    # skip blank lines and comments
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    EXTRA_PACKAGES+=("$line")
  done < "$PACKAGES_FILE"
fi

# Build final package list (deduplicated)
ALL_PACKAGES=("${DEFAULT_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}")
# dedupe while preserving order
declare -A seen
DEDUPED=()
for p in "${ALL_PACKAGES[@]}"; do
  if [[ -z "${seen[$p]:-}" ]]; then
    DEDUPED+=("$p")
    seen[$p]=1
  fi
done
ALL_PACKAGES=("${DEDUPED[@]}")

log "=== Kali tools installer ==="
log "Timestamp: $(timestamp)"
log "Packages to install: ${ALL_PACKAGES[*]}"
log "Result log: $RESULT_LOG"

if [[ $DRY_RUN -eq 1 ]]; then
  log "[DRY RUN] Would install: ${ALL_PACKAGES[*]}"
  exit 0
fi

# Elevate to root if needed
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    log "Not running as root — re-running via sudo..."
    exec sudo bash "$0" "$@"
  else
    err "Script must be run as root (or install sudo on the host)"; exit 1
  fi
fi

# Ensure apt isn't locked (basic wait)
wait_for_apt() {
  local tries=0
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    ((tries++))
    if (( tries > 30 )); then
      err "apt locks persist — aborting."
      exit 1
    fi
    log "apt is locked, waiting... ($tries)"
    sleep 1
  done
}

wait_for_apt

# Update package lists
export DEBIAN_FRONTEND=noninteractive
log "Running apt-get update..."
apt-get update -qq

# Install in batches to avoid super long single apt calls if desired
# We'll just call apt-get install with the full list
log "Installing packages: ${ALL_PACKAGES[*]}"
if ! apt-get install $APT_OPTS "${ALL_PACKAGES[@]}"; then
  err "apt-get install failed — attempting to recover by apt-get -f install"
  apt-get -f $APT_OPTS install || { err "Recovery failed"; exit 1; }
fi

# Post-install: cleanup
log "Cleaning apt caches to reduce image size..."
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Write simple report
{
  echo "Kali install report"
  echo "Timestamp: $(timestamp)"
  echo ""
  echo "Installed packages (attempted):"
  for p in "${ALL_PACKAGES[@]}"; do echo "- $p"; done
  echo ""
  echo "Package versions (dpkg -l):"
  dpkg -l "${ALL_PACKAGES[@]}" 2>/dev/null || echo "(some packages may not be installed or available)"
} > "$RESULT_LOG" || err "Failed to write $RESULT_LOG"

log "Installation completed successfully. Report written to $RESULT_LOG"
log "You can verify by running: dpkg -l ${ALL_PACKAGES[*]}"

exit 0
