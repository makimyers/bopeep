#!/usr/bin/env bash
# Runs bopeep against a fake herdr: checks flock order and what each key sends.
set -euo pipefail
cd "$(dirname "$0")"
fake=$(mktemp -d); trap 'rm -rf "$fake"' EXIT
export BOPEEP_TEST_CALLS=$fake/calls PATH=$fake:$PATH
cat >"$fake/herdr" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "agent list" ]]; then
if [[ -n ${BOPEEP_TEST_JSON:-} ]]; then printf '%s\n' "$BOPEEP_TEST_JSON"; exit; fi
cat <<'JSON'
{"result":{"agents":[
 {"pane_id":"w1:p1","agent":"claude","agent_status":"idle","cwd":"/a"},
 {"pane_id":"w1:p2","agent":"codex","agent_status":"working","cwd":"/b","terminal_title_stripped":"refactor"},
 {"pane_id":"w1:p3","agent":"claude","agent_status":"blocked","cwd":"/c"}]}}
JSON
elif [[ "$*" == *blocked-pane* ]]; then echo "error: agent_blocked" >&2; exit 1
else printf '%s|' "$@" >>"$BOPEEP_TEST_CALLS"; echo >>"$BOPEEP_TEST_CALLS"; fi
EOF
chmod +x "$fake/herdr"

order=$(./bopeep _rows | tail -n +2 | cut -f1 | paste -sd' ' -)
[[ $order == "w1:p3 w1:p2 w1:p1" ]] || { echo "FAIL order: $order"; exit 1; }

./bopeep _enter w1:p2 "hi there" >/dev/null
HERDR_ENV=1 HERDR_PANE_ID=w9:p9 ./bopeep _enter w1:p3 "" >/dev/null
./bopeep _keys w1:p3 "1 enter" >/dev/null
[[ $(env -u HERDR_PANE_ID ./bopeep _enter w1:p3 "") == *"attach {1}"* ]] || { echo "FAIL attach"; exit 1; }
[[ $(./bopeep _enter blocked-pane "yes") == *"ctrl-k"* ]] || { echo "FAIL blocked hint"; exit 1; }
export BOPEEP_ROWS=$fake/rows
[[ $(./bopeep _tick w1:p1 "") == *"+pos(3)+"* ]] || { echo "FAIL tick keeps cursor on pane"; exit 1; }
[[ $(./bopeep _tick w1:p1 "typing") == "refresh-preview" ]] || { echo "FAIL tick freezes while typing"; exit 1; }
want=$'agent|prompt|w1:p2|hi there|\nagent|focus|w1:p3|\nagent|send-keys|w1:p3|1|enter|'
[[ $(<"$BOPEEP_TEST_CALLS") == "$want" ]] || { echo "FAIL calls:"; cat "$BOPEEP_TEST_CALLS"; exit 1; }
./bopeep _enter '' 'do not send' >/dev/null
./bopeep _keys '' 'enter' >/dev/null
[[ $(<"$BOPEEP_TEST_CALLS") == "$want" ]] || { echo "FAIL sent without a selected agent"; exit 1; }

export BOPEEP_TEST_JSON='{"result":{"agents":[]}}'
[[ $(./bopeep _rows) == *'Start an agent in Herdr'* ]] || { echo 'FAIL empty flock'; exit 1; }
export BOPEEP_TEST_JSON='not json'
[[ $(./bopeep _rows) == *'Could not read the agent list'* ]] || { echo 'FAIL malformed response'; exit 1; }
BOPEEP_TEST_JSON=$(jq -nc --arg cwd "$HOME/Projects/example" \
  '{result:{agents:[{pane_id:"w1:p1",agent:"codex",cwd:$cwd,terminal_title_stripped:"hello\tworld\nnot another agent"}]}}')
display=$(./bopeep _rows)
[[ $(printf '%s\n' "$display" | wc -l | tr -d ' ') == 2 && $display == *'hello world not another agent'* ]] \
  || { echo 'FAIL title controls created extra rows or columns'; exit 1; }
[[ $display == *'example'* && $display != *"$HOME/Projects"* ]] || { echo 'FAIL project display'; exit 1; }
unset BOPEEP_TEST_JSON

# Exercise startup as well as the callbacks: GNU mktemp rejects `-t bopeep`.
mkdir "$fake/temp with spaces"
export TMPDIR="$fake/temp with spaces" BOPEEP_TEST_TEMP="$fake/temp-path"
cat >"$fake/fzf" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --version ]]; then echo "${BOPEEP_TEST_FZF_VERSION:-0.74.3} (test)"; exit; fi
[[ -f $BOPEEP_ROWS ]] || exit 3
printf '%s' "$BOPEEP_ROWS" >"$BOPEEP_TEST_TEMP"
exit "${BOPEEP_TEST_EXIT:-0}"
EOF
chmod +x "$fake/fzf"
./bopeep
[[ ! -e $(<"$BOPEEP_TEST_TEMP") ]] || { echo "FAIL temporary file leaked"; exit 1; }
if BOPEEP_TEST_EXIT=2 ./bopeep; then echo "FAIL fzf failure was hidden"; exit 1; fi
BOPEEP_TEST_EXIT=130 ./bopeep
if BOPEEP_TEST_FZF_VERSION=0.73.0 ./bopeep --check >/dev/null 2>&1; then echo 'FAIL accepted old fzf'; exit 1; fi
./bopeep --help >/dev/null
[[ $(./bopeep --version) == 'bopeep 0.1.0' ]] || { echo 'FAIL version'; exit 1; }
./install.sh "$fake/installed with spaces" >/dev/null
cmp bopeep "$fake/installed with spaces/bopeep"
[[ $("$fake/installed with spaces/bopeep" --version) == 'bopeep 0.1.0' ]] || { echo 'FAIL installed executable'; exit 1; }
echo ok
