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

# ── adopt: maturity level gates on shape, not point count ────────────────────
echo "adopt maturity level:"
# A repo passing every check EXCEPT secret hygiene must NOT reach the top level —
# the missing .env floor caps it at L2 even at 5/6.
mkdir -p "$TMP/nosec" && cd "$TMP/nosec" && git init -q >/dev/null 2>&1
printf '# x\n## Keep in sync\n- a\n' > AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md
mkdir -p docs/solutions
lvl="$("$BIN/adopt" --check --json 2>/dev/null | sed 's/.*"level":\([0-9]*\).*/\1/')"
[ "$lvl" = "2" ] && ok "5/6 with no secret hygiene caps at L2 (not the top level)" \
                 || no "expected L2 without .gitignore .env, got L$lvl"
"$BIN/adopt" --check >/dev/null 2>&1 && no "--check should fail below the top level" \
                                     || ok "--check exits nonzero below the top level"
printf '.env\n' > .gitignore
lvl="$("$BIN/adopt" --check --json 2>/dev/null | sed 's/.*"level":\([0-9]*\).*/\1/')"
[ "$lvl" = "3" ] && ok "adding secret hygiene reaches L3" || no "expected L3 after .gitignore, got L$lvl"
# The JSON contract exposes stable check IDs.
"$BIN/adopt" --check --json 2>/dev/null | grep -q '"id":"STD-05"' \
  && ok "--json exposes stable check IDs (STD-05)" || no "STD-05 id missing from --json"

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

# ── review-gate.sh: blocks commit until a marker exists ──────────────────────
echo "review-gate.sh:"
GATE="$BIN/../templates/hooks/scripts/review-gate.sh"
make_repo "$TMP/gaterepo" >/dev/null
export CLAUDE_SESSION_ID="test-gate" TMPDIR="$TMP/gatetmp"
printf '{"tool_input":{"command":"git commit -m x"}}' | bash "$GATE" >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "commit blocked when no review marker" || no "expected exit 2 with no marker"
printf '{"tool_input":{"command":"ls"}}' | bash "$GATE" >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "non-commit command passes through" || no "non-commit should exit 0"
bash "$GATE" --pass code-reviewed >/dev/null 2>&1
printf '{"tool_input":{"command":"git commit -m x"}}' | bash "$GATE" >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "commit allowed after marker written" || no "expected exit 0 after marker"
unset CLAUDE_SESSION_ID TMPDIR

# ── ratchet.sh: fails only when a metric increases ───────────────────────────
echo "ratchet.sh:"
RATCHET="$BIN/../templates/hooks/scripts/ratchet.sh"
make_repo "$TMP/ratchetrepo" >/dev/null
awk 'BEGIN{for(i=0;i<600;i++)print "x"}' > big.py
git add -A && git commit -qm big
bash "$RATCHET" snapshot >/dev/null 2>&1
bash "$RATCHET" check >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "check passes when metrics are unchanged" || no "flat metrics should pass"
awk 'BEGIN{for(i=0;i<700;i++)print "y"}' > big2.py
git add -A && git commit -qm big2
bash "$RATCHET" check >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "check fails when debt increases" || no "increased debt should fail"

# ── adopt: error messages name the problem, not just the usage ───────────────
echo "adopt errors:"
"$BIN/adopt" --chek 2>&1 | grep -q "unknown option '--chek'" \
  && ok "an unknown flag is echoed back by name" \
  || no "unknown flag should be named in the error"

# outside a git repo adopt scores \$PWD on purpose; it must SAY so, or a
# mistyped path reads as a real 0/6 report on the repo the user meant
mkdir -p "$TMP/notgit" && (cd "$TMP/notgit" && "$BIN/adopt" --check 2>&1) \
  | grep -q "not inside a git repo" \
  && ok "a non-git folder is labelled, not scored silently" \
  || no "non-git checkup should say it is not a git repo"

(cd "$ROOT" && "$BIN/adopt" --check 2>&1) | grep -q "not inside a git repo" \
  && no "the non-git note must not appear inside a real repo" \
  || ok "a real repo shows no non-git note"

# the note goes to humans only — --json is a public contract (STD-01..06)
mkdir -p "$TMP/notgit2" && (cd "$TMP/notgit2" && "$BIN/adopt" --check --json 2>/dev/null) \
  | head -1 | grep -q '^{"repo"' \
  && ok "--json stays pure JSON outside a git repo" \
  || no "--json must not be polluted by the non-git note"

# a fix log whose entries lack the §2 fields is one nobody can query — say so,
# but never move the score: the STD-* ids are a public contract
mkdir -p "$TMP/thinlog" && cd "$TMP/thinlog" && git init -q >/dev/null 2>&1
printf '# x\n## Keep in sync\n- a\n' > AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md
printf '.env\n' > .gitignore
mkdir -p docs/solutions
printf -- '---\ntags: [a]\ndate: 2026-01-01\n---\n\n## Problem\nx\n' > docs/solutions/drifted.md
"$BIN/adopt" --check 2>&1 | grep -q 'missing required frontmatter' \
  && ok "a fix-log entry missing §2 fields is reported" \
  || no "drifted fix-log frontmatter should be reported"
[ "$("$BIN/adopt" --check --json 2>/dev/null | sed 's/.*"score":\([0-9]*\).*/\1/')" = "6" ] \
  && ok "a drifted fix log still scores 6/6 (score is not moved)" \
  || no "the frontmatter note must not change the score"

# every failing check names a concrete fix — a scorecard that only says what is
# absent makes the reader guess the remedy
mkdir -p "$TMP/fixtext"
out="$(cd "$TMP/fixtext" && "$BIN/adopt" --check 2>&1)"
printf '%s' "$out" | grep -q 'what to fix' \
  && ok "a failing check prints a 'what to fix' block" \
  || no "failing checks must print remediation text"
n=$(printf '%s\n' "$out" | grep -cE '^   . STD-0[1-6] [^ ].*')
[ "$n" = "6" ] \
  && ok "all six failing checks each get their own fix line" \
  || no "expected 6 non-empty fix lines on an empty folder, got $n"
printf '%s' "$out" | grep -q "STD-05 add '.env' to .gitignore" \
  && ok "a fix line names the actual remedy, not just the id" \
  || no "STD-05 must print its remediation text"
printf '%s' "$out" | grep -q 'AGENTS.md — the one welcome note' \
  && ok "the scorecard still prints plain-English labels, not raw ids" \
  || no "row() must print the label, not the check id"
(cd "$ROOT" && "$BIN/adopt" --check 2>&1) | grep -q 'what to fix' \
  && no "a 6/6 repo must not print a fix block" \
  || ok "a fully-passing repo prints no fix block"

# the shipped templates are scaffolding, not the repo's own entries. Use a
# deliberately THIN EXAMPLE-* file: the real templates carry full frontmatter, so
# copying them would pass whether or not the name-based exclusion works.
printf -- '---\nmodule: m\ntags: [a]\nproblem_type: bug\ndate: 2026-01-01\n---\n' > docs/solutions/drifted.md
printf -- '---\ntags: [a]\n---\n' > docs/solutions/EXAMPLE-thin.md
"$BIN/adopt" --check 2>&1 | grep -q 'missing required frontmatter' \
  && no "EXAMPLE-* templates must not count as drifted entries" \
  || ok "shipped EXAMPLE-* templates don't trigger the frontmatter note"

# §5: agent involvement is never invisible, even under a human author line
make_repo "$TMP/adoptcommit" >/dev/null
"$BIN/adopt" --yes >/dev/null 2>&1
git log -1 --format='%B' 2>/dev/null | grep -qi '^Assisted-by:' \
  && ok "adopt's commit carries an agent-authorship trailer" \
  || no "adopt commit must disclose agent authorship (STANDARD.md §5)"

# "deletes nothing" is the promise adopt makes on screen; hold it to that
git log -1 --shortstat 2>/dev/null | grep -q 'deletion' \
  && no "adopt must not delete lines when adopting an existing repo" \
  || ok "adopt only adds when adopting a repo that already has files"

# ── doc-gate-check: AGENTS.md commands stay pinned to the CI gates ───────────
echo "doc-gate-check:"
GATE_SRC="$BIN/doc-gate-check"
(cd "$ROOT" && "$GATE_SRC") >/dev/null 2>&1 \
  && ok "this repo's documented commands match its CI gates" \
  || no "doc/CI drift: $( (cd "$ROOT" && "$GATE_SRC") 2>&1 | tail -2 | tr '\n' ' ')"

# a fixture repo lets us prove the failure paths, not just the happy one
gate_fixture() {   # $1 = dir; copies the real repo's doc + workflow
  rm -rf "$1"; mkdir -p "$1/bin" "$1/.github/workflows"
  cp "$GATE_SRC" "$1/bin/"
  cp "$ROOT/AGENTS.md" "$1/AGENTS.md"
  cp "$ROOT/.github/workflows/ci.yml" "$1/.github/workflows/ci.yml"
  # its own git root, so the script's "am I in my own repo?" guard is satisfied
  git -C "$1" init -q 2>/dev/null
}

gate_fixture "$TMP/gate-drift"
# CI grows a path that AGENTS.md never learns about
sed 's|^\( *\)shellcheck -S warning \(bin/\*.*\)$|\1shellcheck -S warning \2 scripts/new/*.sh|' \
  "$TMP/gate-drift/.github/workflows/ci.yml" > "$TMP/gate-drift/.github/workflows/ci.new" \
  && mv "$TMP/gate-drift/.github/workflows/ci.new" "$TMP/gate-drift/.github/workflows/ci.yml"
(cd "$TMP/gate-drift" && bin/doc-gate-check) >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "drift between AGENTS.md and ci.yml fails" || no "drift should fail"

gate_fixture "$TMP/gate-absent"
# both sides lose the command: an absent gate must fail, never compare "" = ""
printf '# no commands here\n' > "$TMP/gate-absent/AGENTS.md"
printf 'jobs: {}\n' > "$TMP/gate-absent/.github/workflows/ci.yml"
(cd "$TMP/gate-absent" && bin/doc-gate-check) >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "a missing gate on both sides fails (no empty-match pass)" \
  || no "both-empty should fail, not pass"

# the file-set pair compares resolved paths, not strings: CI globs a directory
# where the doc names one file, so only real coverage differences may fail
gate_files_fixture() {   # $1 = dir; a fixture with the real globbable trees
  rm -rf "$1"; mkdir -p "$1/.github/workflows"
  cp -R "$ROOT/bin" "$ROOT/tests" "$ROOT/templates" "$ROOT/install.sh" "$1/"
  cp "$ROOT/AGENTS.md" "$1/AGENTS.md"
  cp "$ROOT/.github/workflows/ci.yml" "$1/.github/workflows/ci.yml"
  git -C "$1" init -q 2>/dev/null
}

gate_files_fixture "$TMP/gate-narrow"
# the doc quietly stops claiming a directory CI still checks
sed 's|^bash -n .*|bash -n bin/* install.sh templates/hooks/scripts/*.sh templates/git/hooks/pre-commit|' \
  "$TMP/gate-narrow/AGENTS.md" > "$TMP/gate-narrow/A" && mv "$TMP/gate-narrow/A" "$TMP/gate-narrow/AGENTS.md"
(cd "$TMP/gate-narrow" && bin/doc-gate-check) >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "a doc that covers fewer files than CI fails" \
  || no "narrowed doc coverage should fail"

# run from another repo it must refuse, not silently report on its own tree:
# a plausible "ok" about a repo the caller isn't looking at is the worst answer
make_repo "$TMP/foreign" >/dev/null
"$BIN/doc-gate-check" >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "doc-gate-check refuses to run against a foreign repo" \
  || no "running outside its own repo must exit 2, not report ok"

gate_files_fixture "$TMP/gate-widen"
# a new hook lands in CI's glob; the doc names only pre-commit and misses it
printf '#!/bin/bash\necho hi\n' > "$TMP/gate-widen/templates/git/hooks/pre-push"
(cd "$TMP/gate-widen" && bin/doc-gate-check) >/dev/null 2>&1
[ "$?" -eq 1 ] && ok "a new file inside CI's glob that the doc misses fails" \
  || no "widened CI glob should fail"

# ── absence-check: zero hits ≠ absent unless the repo owns the surface ───────
echo "absence-check:"
ac_repo="$TMP/acrepo"
mkdir -p "$ac_repo/src"
printf 'export function requireAuth(){}\n' > "$ac_repo/src/auth.ts"
printf 'const x = 1\n'                      > "$ac_repo/src/app.ts"

state(){ "$BIN/absence-check" --json "$1" "$2" | sed -E 's/.*"state":"([^"]+)".*/\1/'; }

[ "$(state 'requireAuth' "$ac_repo")" = "CONFIRMED" ] \
  && ok "a found control is CONFIRMED" || no "requireAuth should be CONFIRMED"

# off-source control, no IaC in the repo → UNVERIFIED, never a false NOT_FOUND
line="$("$BIN/absence-check" --controls "$ac_repo" | awk '$1=="backups"{print $2}')"
[ "$line" = "UNVERIFIED" ] \
  && ok "an off-source control with no IaC is UNVERIFIED, not absent" \
  || no "backups with no IaC should be UNVERIFIED, got: $line"

# on-source control: its absence in app code IS evidence, so NOT_FOUND even w/o IaC
line="$("$BIN/absence-check" --controls "$ac_repo" | awk '$1=="rate-limit"{print $2}')"
[ "$line" = "NOT_FOUND" ] \
  && ok "an on-source control missing from app code is NOT_FOUND without IaC" \
  || no "rate-limit with no IaC should be NOT_FOUND, got: $line"

# add IaC → the repo now owns that surface → the same miss becomes NOT_FOUND
printf 'FROM node:20\n' > "$ac_repo/Dockerfile"
line="$("$BIN/absence-check" --controls "$ac_repo" | awk '$1=="backups"{print $2}')"
[ "$line" = "NOT_FOUND" ] \
  && ok "the same miss becomes NOT_FOUND once the repo ships IaC" \
  || no "backups with IaC should be NOT_FOUND, got: $line"

# the script must not report its own control literals as a match
[ "$(state 'RateLimiter' "$BIN")" = "NOT_FOUND" ] \
  && ok "scanning bin/ does not self-match the control patterns" \
  || no "absence-check should exclude itself from the scan"

# a real control token that lives ONLY in docs and a *.test file must not
# confirm the control: scope is application source, not the whole text tree.
mkdir -p "$ac_repo/docs"
printf 'Someday run pg_dump nightly.\n'            > "$ac_repo/docs/plan.md"
printf "it('runs pg_dump', () => {})\n"            > "$ac_repo/src/sync.test.ts"
line="$("$BIN/absence-check" --controls "$ac_repo" | awk '$1=="backups"{print $2}')"
[ "$line" = "NOT_FOUND" ] \
  && ok "a real control token only in docs/test files does not confirm it" \
  || no "docs/test-fixture mentions should not confirm a control, got: $line"

# but the same token in real source DOES confirm it
printf 'import { exec } from "child_process"; exec("pg_dump db")\n' > "$ac_repo/src/backup.ts"
line="$("$BIN/absence-check" --controls "$ac_repo" | awk '$1=="backups"{print $2}')"
[ "$line" = "CONFIRMED" ] \
  && ok "the same token in application source confirms the control" \
  || no "a control in src should be CONFIRMED, got: $line"

# false NOT_FOUND is the tool's worst failure, and it does NOT claim to prevent
# it: a control present but written in a form no pattern matches reads NOT_FOUND.
# This test documents that honestly — an auth check via a name the pattern misses
# is not confirmed, so NOT_FOUND must never be read as "the control is absent".
fn_repo="$TMP/acrepo-fn"
mkdir -p "$fn_repo/src"
printf 'export function gateRequest(u){ return u.session }\n' > "$fn_repo/src/guard.ts"
[ "$(state 'gateRequest' "$fn_repo")" = "CONFIRMED" ] \
  && ok "the control exists (found by its real name)" \
  || no "gateRequest should be findable by its own name"
line="$("$BIN/absence-check" --controls "$fn_repo" | awk '$1=="auth"{print $2}')"
[ "$line" = "NOT_FOUND" ] \
  && ok "a present control the patterns miss reads NOT_FOUND (a known limit, not proof of absence)" \
  || no "auth via an unmatched name should be NOT_FOUND, got: $line"

# substring guard: `joi` must not match inside `join`. This exact false positive
# (379 junk hits) is what an earlier loose pattern produced on a real repo.
sub_repo="$TMP/acrepo-sub"
mkdir -p "$sub_repo/src"
printf "const s = ['a','b'].join('+')\n" > "$sub_repo/src/util.ts"
line="$("$BIN/absence-check" --controls "$sub_repo" | awk '$1=="input-valid"{print $2}')"
[ "$line" = "NOT_FOUND" ] \
  && ok "the input-valid pattern does not match 'joi' inside 'join'" \
  || no "join() must not confirm input-valid, got: $line"

echo ""
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
