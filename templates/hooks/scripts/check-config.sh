#!/bin/bash
set -euo pipefail

# SessionStart self-healing config check (house standard).
# Does two generically-useful, cross-platform-safe things: ensure a required dir exists, and lock down a loose-permission .env.
#
# Per-repo: edit ENV_FILE and ensure-dir paths below for this repo's config.

# --- 1. Ensure required dirs exist (edit for this repo) ---------------------
# Example: a build output / cache / data dir that must exist or first run fails.
# mkdir -p "${SOME_OUTPUT_DIR:-./.cache}" 2>/dev/null || true

# --- 2. Lock down a loose-permission .env -----------------------------------
# Set to the secrets file this repo uses. Common: ".env", ".env.local".
ENV_FILE="${AGENT_ENV_FILE:-.env.local}"

check_perms() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Git-for-Windows / MSYS / Cygwin run stat in noacl mode (always 644) — skip.
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
  esac
  local perms
  # GNU stat (Linux) first, BSD stat (macOS) fallback.
  perms=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null || echo "")
  if [[ -n "$perms" && "$perms" != "600" && "$perms" != "400" ]]; then
    if chmod 600 "$file" 2>/dev/null; then
      echo "config-check: WARNING — $file had permissions $perms — auto-fixed with chmod 600"
    else
      echo "config-check: WARNING — $file has permissions $perms (should be 600). Fix: chmod 600 $file"
    fi
  fi
}

check_perms "$ENV_FILE"

# Last command must succeed so the hook never leaks a nonzero exit to the driver.
exit 0
