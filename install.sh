#!/bin/bash
# install.sh — one-line installer for agent-standard.
#
#   curl -fsSL https://raw.githubusercontent.com/anmoln7/agent-standard-oss/main/install.sh | bash
#
# Installs to ~/.agent-standard (override: AGENT_STD_HOME), then puts the
# scripts on your PATH: symlinks into ~/.local/bin when that's already on
# PATH, otherwise adds one line to your shell profile.
#
# Safe to re-run (updates in place). No sudo. Touches nothing outside your
# home directory. Fully non-interactive, so it works via `curl | bash`.
set -uo pipefail

REPO="${AGENT_STD_REPO:-https://github.com/anmoln7/agent-standard-oss}"
DEST="${AGENT_STD_HOME:-$HOME/.agent-standard}"
BIN="$DEST/bin"

command -v git >/dev/null 2>&1 || { echo "install: git is required (https://git-scm.com)"; exit 1; }

# 1. get (or update) the code
if [ -d "$DEST/.git" ]; then
  echo "→ updating existing install in ${DEST/$HOME/~}"
  git -C "$DEST" pull -q --ff-only 2>/dev/null \
    || echo "  (couldn't fast-forward — local changes in $DEST? keeping it as-is)"
else
  echo "→ installing to ${DEST/$HOME/~}"
  git clone -q --depth 1 "$REPO" "$DEST" 2>/dev/null \
    || git clone -q "$REPO" "$DEST" || { echo "install: clone failed"; exit 1; }
fi

# 2. put the scripts on PATH
on_path=0
case ":$PATH:" in
  *":$HOME/.local/bin:"*)
    mkdir -p "$HOME/.local/bin"
    for f in "$BIN"/*; do
      [ -f "$f" ] && [ -x "$f" ] && ln -sf "$f" "$HOME/.local/bin/$(basename "$f")"
    done
    echo "→ linked the scripts into ~/.local/bin (already on your PATH)"
    on_path=1
    ;;
esac
if [ "$on_path" -eq 0 ]; then
  case ":$PATH:" in *":$BIN:"*) on_path=1 ;; esac   # already added on a previous run
fi
if [ "$on_path" -eq 0 ]; then
  profile="$HOME/.profile"
  case "${SHELL:-}" in
    */zsh)  profile="$HOME/.zshrc" ;;
    */bash) profile="$HOME/.bashrc" ;;
  esac
  if ! grep -qsF "$BIN" "$profile"; then
    printf '\nexport PATH="%s:$PATH"  # agent-standard\n' "$BIN" >> "$profile"
  fi
  echo "→ added $BIN to PATH in ${profile/$HOME/~}"
  echo "  (open a new terminal, or run:  export PATH=\"$BIN:\$PATH\")"
fi

echo ""
echo "✓ agent-standard installed."
echo ""
echo "  Next, inside any project folder:"
echo "    adopt            # the friendly walkthrough"
echo "    adopt --check    # just the scorecard"
echo ""
echo "  Using Claude Code? Let it do everything for you:"
echo "    /plugin marketplace add anmoln7/agent-standard-oss"
echo "    /plugin install agent-standard@agent-standard"
echo "    /agent-standard:adopt"
