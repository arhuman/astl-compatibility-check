#!/bin/sh
# The published comparison: astl against ansible-lint on the same corpus.
#
# This is not the speed guard. bench.sh is one-sided by design (it times astl
# against a budget and gates CI); this script exists because the numbers quoted
# in astl's README and docs/performance.md compare two linters, and a reader who
# wants to check them needs the command that produced them, not a guard that
# never runs ansible-lint.
#
# The comparison is asymmetric and the output says so: ansible-lint is also
# running its syntax-check subprocess and the 12 rules astl does not implement.
# The honest headline numbers are cold start and the single playbook, where the
# gap is interpreter and import overhead that exists before any rule runs.
#
# Requires hyperfine. ansible-lint comes from a throwaway venv built on the same
# pins as the golden files, so the comparison cannot drift from the contract.
set -eu

ASTL_REPO=${1:-../ansible-static-lint}
CORPUS=${2:-corpus}
RUNS=${3:-5}

. "$(dirname "$0")/upstream.sh"

command -v hyperfine >/dev/null || {
  echo "bench-compare: hyperfine is required (brew install hyperfine)" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
BIN=$tmp/astl

if [ -f "$ASTL_REPO/go.mod" ]; then
  (cd "$ASTL_REPO" && go build -o "$BIN" ./cmd/astl)
else
  echo "bench-compare: no checkout of astl at $ASTL_REPO" >&2
  exit 1
fi

# Same neutralization as bench.sh: astl and ansible-lint both resolve a
# yamllint configuration, which decides how many yaml rules run. Measuring the
# developer's own config would make the published numbers unreproducible.
unset YAMLLINT_CONFIG_FILE
XDG_CONFIG_HOME=$tmp/xdg
export XDG_CONFIG_HOME

echo "bench-compare: installing pinned upstream ($UPSTREAM_PIP_SPEC)" >&2
python3 -m venv "$tmp/venv"
# shellcheck disable=SC2086  # the spec is three intentionally separate pins
"$tmp/venv/bin/pip" install -q $UPSTREAM_PIP_SPEC
AL=$tmp/venv/bin/ansible-lint

"$AL" --version >&2

# One 6-line playbook, written here so the figure does not depend on which
# corpus file happens to be small this release.
cat > "$tmp/one.yml" <<'PLAY'
- name: Example
  hosts: localhost
  tasks:
    - name: Ping the host
      ansible.builtin.ping:
PLAY

echo
echo "== Cold start (--version) =="
hyperfine --warmup 3 --runs "$RUNS" -N \
  --command-name 'astl --version'         "$BIN --version" \
  --command-name 'ansible-lint --version' "$AL --version"

echo
echo "== One 6-line playbook =="
hyperfine --warmup 3 --runs "$RUNS" -i \
  --command-name 'astl one.yml'         "$BIN $tmp/one.yml" \
  --command-name 'ansible-lint one.yml' "$AL --offline $tmp/one.yml"

echo
echo "== 478-file corpus =="
hyperfine --warmup 1 --runs "$RUNS" -i \
  --command-name 'astl corpus'         "$BIN $CORPUS" \
  --command-name 'ansible-lint corpus' "$AL --offline $CORPUS"

echo
echo "== Max RSS on the corpus =="
case $(uname -s) in
  Darwin)
    /usr/bin/time -l "$BIN" "$CORPUS" 2>&1 >/dev/null | grep -i 'maximum resident' || true
    /usr/bin/time -l "$AL" --offline "$CORPUS" 2>&1 >/dev/null | grep -i 'maximum resident' || true
    ;;
  *)
    /usr/bin/time -v "$BIN" "$CORPUS" 2>&1 >/dev/null | grep -i 'Maximum resident' || true
    /usr/bin/time -v "$AL" --offline "$CORPUS" 2>&1 >/dev/null | grep -i 'Maximum resident' || true
    ;;
esac

echo
echo "Read the corpus ratio with care: ansible-lint is also running its"
echo "syntax-check subprocess and the 12 rules astl does not implement."
