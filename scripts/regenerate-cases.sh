#!/bin/sh
# Rebuild golden/cases_pep8.txt by running the pinned ansible-lint over cases/.
#
# cases/ holds fixtures this project wrote, for divergences the upstream corpus
# does not exercise. It is regenerated separately because scripts/regenerate.sh
# deletes corpus/ and refills it from upstream, which would destroy them.
#
# The golden output is still ansible-lint's, from the same pinned version,
# because the contract is what upstream does and not what we think it should do.
# The pins come from scripts/upstream.sh, sourced by both regeneration scripts,
# so they cannot drift apart.
#
# Usage:
#   scripts/regenerate-cases.sh          # install the pinned ansible-lint
#   ANSIBLE_LINT=/path/to/ansible-lint scripts/regenerate-cases.sh
#
# Requirements: python3 (3.10+) and pip, unless ANSIBLE_LINT is set.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

. "$ROOT/scripts/rules.sh"
. "$ROOT/scripts/upstream.sh"

if [ -n "${ANSIBLE_LINT:-}" ]; then
  LINT="$ANSIBLE_LINT"
  got=$("$LINT" --version 2>/dev/null | head -1 | awk '{print $2}')
  if [ "$got" != "$UPSTREAM_VERSION" ]; then
    echo "FAIL: ANSIBLE_LINT is version $got, the contract is pinned to $UPSTREAM_VERSION" >&2
    exit 1
  fi
  echo "using ansible-lint $got at $LINT"
else
  echo "installing $UPSTREAM_PIP_SPEC"
  python3 -m venv "$WORK/venv"
  "$WORK/venv/bin/pip" install --quiet --upgrade pip
  # shellcheck disable=SC2086  # the spec is three deliberate pip arguments, not one
  "$WORK/venv/bin/pip" install --quiet $UPSTREAM_PIP_SPEC
  LINT="$WORK/venv/bin/ansible-lint"
fi

# Run from the repository root so reported paths are already rooted at cases/.
# The environment is neutralized exactly as scripts/regenerate.sh does it, and
# for the reasons documented there: both goldens must describe the stock policy,
# not whatever yamllint config and collections the regenerating machine carries.
echo "running ansible-lint over cases/"
cd "$ROOT"
unset YAMLLINT_CONFIG_FILE
XDG_CONFIG_HOME="$WORK/xdg"
ANSIBLE_HOME="$WORK/ansible"
export XDG_CONFIG_HOME ANSIBLE_HOME
"$LINT" --offline --nocolor -f pep8 cases > "$WORK/raw.txt" || true

# Sorted for the same reason as the corpus golden: ordering carries no contract,
# and an unsorted file turns every regeneration into an unreviewable diff.
grep -E "^[^ ]+:[0-9]+(:[0-9]+)?: ($RULES)(\[|:)" "$WORK/raw.txt" \
  | sed -e "s#^$ROOT/##" -e 's#^\./##' \
  | LC_ALL=C sort > "$ROOT/golden/cases_pep8.txt"

echo "cases golden lines: $(wc -l < "$ROOT/golden/cases_pep8.txt")"
cat <<'EOF'

golden/cases_pep8.txt is regenerated.

Unlike the corpus contract, cases/ admits no expected extras: a fixture is
added here precisely because astl and ansible-lint should agree on it. If the
check reports an extra, astl is wrong, or the fixture is testing something it
did not mean to.
EOF
