#!/bin/bash
# run-tests.sh — plain-bash tests for the bin/ scripts. No deps beyond git
# (npm needed for one land-safely test; it is skipped when npm is absent).
#
#   tests/run-tests.sh          # run everything, exit nonzero on any failure
#
# Each test runs against a throwaway git repo under mktemp, with HOME overridden
# so nothing touches your real ~/.config.
set -u

BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"   # isolate ~/.config used by pr-risk
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
git config --file "$GIT_CONFIG_GLOBAL" user.name test
git config --file "$GIT_CONFIG_GLOBAL" user.email test@example.invalid
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main

pass=0; fail=0
ok(){ echo "  ✓ $1"; pass=$((pass+1)); }
no(){ echo "  ✗ $1"; fail=$((fail+1)); }

make_repo(){ # make_repo <path>  — git repo with one commit on main
  git init -q "$1" && cd "$1" || exit 1
  echo "hello" > README.md
  git add -A && git commit -qm "init"
}

# ── pr-risk: novel until learned twice ───────────────────────────────────────
echo "pr-risk:"
make_repo "$TMP/riskrepo"
git switch -qc change
echo "docs edit" >> README.md
git commit -qam "docs edit"

out="$("$BIN/pr-risk" classify main)"
[ "$(echo "$out" | tail -1)" = "novel" ] && ok "first-time docs change classifies novel" \
                                         || no "expected novel, got: $(echo "$out" | tail -1)"
"$BIN/pr-risk" learn main >/dev/null
"$BIN/pr-risk" learn main >/dev/null
out="$("$BIN/pr-risk" classify main)"
[ "$(echo "$out" | tail -1)" = "routine" ] && ok "same signatures classify routine after 2 approvals" \
                                           || no "expected routine, got: $(echo "$out" | tail -1)"

# ── wt: parallel hand-out must not share a worktree ──────────────────────────
echo "wt:"
make_repo "$TMP/wtrepo"
w1="$("$BIN/wt" new)"
w2="$("$BIN/wt" new)"
[ -n "$w1" ] && [ -n "$w2" ] && [ "$w1" != "$w2" ] && ok "two wt-new calls hand out distinct worktrees" \
                                                   || no "worktrees collided: '$w1' vs '$w2'"
"$BIN/wt" free "$w1" >/dev/null
w3="$("$BIN/wt" new)"
[ "$w3" = "$w1" ] && ok "freed worktree is reused" || no "expected reuse of $w1, got $w3"
"$BIN/wt" clean >/dev/null 2>&1

# ── land-safely: failing tests must gate (abort before push) ─────────────────
echo "land-safely:"
if command -v npm >/dev/null 2>&1; then
  make_repo "$TMP/gaterepo-origin"
  cd "$TMP" && git clone -q "$TMP/gaterepo-origin" gaterepo && cd gaterepo || exit 1
  printf '{"name":"x","version":"0.0.0","scripts":{"test":"exit 1"}}\n' > package.json
  if "$BIN/land-safely" "failing change" >/dev/null 2>&1; then
    no "land-safely pushed despite failing tests"
  else
    ok "land-safely aborts when npm test fails"
  fi
  git -C "$TMP/gaterepo-origin" show-ref -q --heads "refs/heads/land/failing-change" \
    && no "failing branch reached the remote" \
    || ok "nothing was pushed to the remote"
else
  echo "  - skipped (npm not installed)"
fi

# ── adopt: the friendly onboarding wizard ────────────────────────────────────
echo "adopt:"
mkdir -p "$TMP/adoptrepo" && cd "$TMP/adoptrepo" || exit 1
printf 'My project notes\n' > CLAUDE.md
"$BIN/adopt" --check >/dev/null 2>&1 && no "adopt --check should fail before adoption" \
                                     || ok "adopt --check fails on an unadopted project"
"$BIN/adopt" --yes >/dev/null 2>&1
grep -q "My project notes" AGENTS.md 2>/dev/null && ok "existing CLAUDE.md content migrated into AGENTS.md" \
                                                 || no "CLAUDE.md content missing from AGENTS.md"
[ "$(head -1 CLAUDE.md)" = "@AGENTS.md" ] && ok "CLAUDE.md is the one-line include" \
                                          || no "CLAUDE.md is not the include: $(head -1 CLAUDE.md)"
[ -d docs/solutions ] && ok "fix-log directory created" || no "docs/solutions missing"
"$BIN/adopt" --check >/dev/null 2>&1 && ok "adopt --check passes after adoption" \
                                     || no "adopt --check still failing after adoption"
"$BIN/adopt" --yes >/dev/null 2>&1   # second run must change nothing
[ "$(grep -c '^## Keep in sync' AGENTS.md)" = "1" ] && ok "second run is idempotent (no duplicate sections)" \
                                                    || no "duplicate Keep-in-sync sections after re-run"
mkdir -p "$TMP/freshrepo" && cd "$TMP/freshrepo" || exit 1
"$BIN/adopt" --yes >/dev/null 2>&1
[ -f AGENTS.md ] && grep -q "^# freshrepo" AGENTS.md && ok "starter AGENTS.md created when none exists" \
                                                     || no "starter AGENTS.md missing or unnamed"

# ── crew: CREW_MAX_PARALLEL caps a batch, remainder stays queued ─────────────
echo "crew:"
mkdir -p "$TMP/shim"
printf '#!/bin/sh\nexit 0\n' > "$TMP/shim/claude"
printf '#!/bin/sh\nexit 0\n' > "$TMP/shim/tmux"
chmod +x "$TMP/shim/claude" "$TMP/shim/tmux"
make_repo "$TMP/crewrepo"
PATH="$TMP/shim:$PATH" "$BIN/crew" add "$TMP/crewrepo" "task one"   >/dev/null
PATH="$TMP/shim:$PATH" "$BIN/crew" add "$TMP/crewrepo" "task two"   >/dev/null
PATH="$TMP/shim:$PATH" "$BIN/crew" add "$TMP/crewrepo" "task three" >/dev/null
PATH="$TMP/shim:$PATH" CREW_MAX_PARALLEL=1 "$BIN/crew" run >/dev/null 2>&1
queued="$(grep -c . "$HOME/.config/agent-standard/crew/queue.tsv")"
[ "$queued" = "2" ] && ok "cap of 1 launches one task, two stay queued" \
                    || no "expected 2 queued after capped run, got $queued"
PATH="$TMP/shim:$PATH" CREW_MAX_PARALLEL=0 "$BIN/crew" run >/dev/null 2>&1
queued="$(grep -c . "$HOME/.config/agent-standard/crew/queue.tsv")"
[ "$queued" = "0" ] && ok "cap of 0 (unlimited) drains the queue" \
                    || no "expected empty queue after unlimited run, got $queued"

# ── install.sh: one-liner installer ──────────────────────────────────────────
echo "install.sh:"
ROOT="$(cd "$BIN/.." && pwd)"
idir="$TMP/installhome"; mkdir -p "$idir"
HOME="$idir" SHELL=/bin/zsh AGENT_STD_REPO="$ROOT" AGENT_STD_HOME="$idir/.agent-standard" \
  bash "$ROOT/install.sh" >/dev/null 2>&1
[ -x "$idir/.agent-standard/bin/adopt" ] && ok "installer clones and adopt is executable" \
                                         || no "adopt missing/not executable after install"
HOME="$idir" SHELL=/bin/zsh AGENT_STD_REPO="$ROOT" AGENT_STD_HOME="$idir/.agent-standard" \
  bash "$ROOT/install.sh" >/dev/null 2>&1
[ "$(grep -c 'agent-standard' "$idir/.zshrc")" = "1" ] && ok "re-run doesn't duplicate the PATH line" \
                                                       || no "PATH line duplicated on re-run"

# ── plugin surface: valid JSON, versions in lockstep, commands wired ─────────
if command -v jq >/dev/null 2>&1; then
  echo "plugin:"
  jq -e .name "$ROOT/.claude-plugin/plugin.json" >/dev/null 2>&1 \
    && jq -e '.plugins[0].name' "$ROOT/.claude-plugin/marketplace.json" >/dev/null 2>&1 \
    && ok "plugin.json and marketplace.json are valid JSON with names" \
    || no "plugin metadata invalid"
  # VERSION is the single source; sync-version --check gates the derived files
  # (plugin.json, marketplace.json, README pin) against it.
  if "$ROOT/bin/sync-version" --check >/dev/null 2>&1; then
    ok "plugin.json, marketplace.json, and README pin VERSION ($(tr -d '[:space:]' < "$ROOT/VERSION"))"
  else
    no "version drift — run bin/sync-version: $("$ROOT/bin/sync-version" --check 2>&1 | tail -1)"
  fi
fi

echo "commands:"
missing=""
for f in "$ROOT"/commands/*.md; do
  # every ${CLAUDE_PLUGIN_ROOT}/bin/<script> a command references must exist
  for s in $(grep -o 'CLAUDE_PLUGIN_ROOT}/bin/[a-z-]*' "$f" | sed 's|.*/bin/||' | sort -u); do
    [ -x "$ROOT/bin/$s" ] || missing="$missing $(basename "$f")->bin/$s"
  done
done
[ -z "$missing" ] && ok "command files reference existing bin/ scripts" \
                  || no "commands reference missing scripts:$missing"

# ── repo-audit: twin-dir drift check ─────────────────────────────────────────
echo "repo-audit:"
mkdir -p "$TMP/twina" "$TMP/twinb" "$TMP/emptyroot"
printf 'same\n' > "$TMP/twina/shared";  printf 'same\n'  > "$TMP/twinb/shared"
printf 'one\n'  > "$TMP/twina/drifted"; printf 'two\n'   > "$TMP/twinb/drifted"
printf 'solo\n' > "$TMP/twina/only-in-a"
out="$(AGENT_STD_ROOTS="$TMP/emptyroot" AGENT_STD_TWIN_DIRS="$TMP/twina:$TMP/twinb" "$BIN/repo-audit")"
echo "$out" | grep -q '\*\*drifted\*\* differs' && ok "twin check flags the differing file" \
                                                || no "drifted file not flagged"
echo "$out" | grep -q '\*\*shared\*\*'  && no "identical file wrongly flagged" \
                                        || ok "identical file not flagged"
echo "$out" | grep -q '\*\*only-in-a\*\*' && no "unpaired file wrongly flagged" \
                                          || ok "file present in only one dir is ignored"
out="$(AGENT_STD_ROOTS="$TMP/emptyroot" "$BIN/repo-audit")"
echo "$out" | grep -q 'not configured' && ok "twin check is opt-in (skips when unset)" \
                                       || no "unset AGENT_STD_TWIN_DIRS should skip the check"

# ── README → STANDARD.md anchor links resolve ────────────────────────────────
echo "readme anchors:"
grep '^##' "$ROOT/STANDARD.md" | sed -e 's/^#\{1,\} //' -e 's/`//g' \
  | awk '{s=tolower($0); gsub(/[^a-z0-9 -]/,"",s); gsub(/ /,"-",s); print s}' > "$TMP/anchors"
broken=""
while IFS= read -r a; do
  grep -qx "$a" "$TMP/anchors" || broken="$broken $a"
done < <(grep -o 'STANDARD\.md#[a-z0-9-]*' "$ROOT/README.md" | sed 's/.*#//' | sort -u)
[ -z "$broken" ] && ok "every README link into STANDARD.md matches a real heading" \
                 || no "broken README anchors:$broken"

# ── check-config.sh: locks down a loose .env ─────────────────────────────────
echo "check-config.sh:"
cd "$TMP" && mkdir -p cfg && cd cfg || exit 1
touch .env.local && chmod 644 .env.local
bash "$BIN/../templates/hooks/scripts/check-config.sh" >/dev/null
perms="$(stat -c '%a' .env.local 2>/dev/null || stat -f '%Lp' .env.local)"
[ "$perms" = "600" ] && ok ".env.local auto-chmodded to 600" || no ".env.local is $perms, expected 600"

echo ""
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
