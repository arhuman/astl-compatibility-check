#!/bin/sh
# Speed regression guard: build astl and fail when linting the corpus exceeds
# the wall-clock budget.
#
# This guards a property, not a number: astl's cost must stay nearly independent
# of how many rules run, because each rule is a predicate over an already-parsed
# file. A change that breaks that (a rule re-reading files, a quadratic walk)
# multiplies the corpus time and trips this, while machine noise cannot, because
# the budget sits several times above the current time.
#
# Best of N runs, because the minimum is the least noisy estimate of the cost and
# a real regression moves it too.
set -eu

ASTL_REPO=${1:?usage: bench.sh <astl-repo> <corpus-dir> [budget_ms] [runs]}
CORPUS=${2:?usage: bench.sh <astl-repo> <corpus-dir> [budget_ms] [runs]}
BUDGET_MS=${3:-150}
RUNS=${4:-5}
ASTL_VERSION=${ASTL_VERSION:-latest}
LINTER_PKG=github.com/arhuman/ansible-static-lint/cmd/astl

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
BIN=$tmp/astl

# Same astl resolution as check_test.go, and it must stay the same: a time
# measured against a different binary than the golden check ran would let the two
# gates disagree without saying so.
if [ -f "$ASTL_REPO/go.mod" ]; then
  (cd "$ASTL_REPO" && go build -o "$BIN" ./cmd/astl)
else
  echo "bench: no checkout of astl at $ASTL_REPO, using $LINTER_PKG@$ASTL_VERSION" >&2
  GOBIN=$tmp go install "$LINTER_PKG@$ASTL_VERSION"
fi

# Measure the same work everywhere: astl honours the machine's yamllint
# configuration, which decides how many yaml rules run and so how long the corpus
# takes. XDG_CONFIG_HOME points at an empty directory rather than being unset,
# because unsetting it falls back to ~/.config.
unset YAMLLINT_CONFIG_FILE
XDG_CONFIG_HOME=$tmp/xdg
export XDG_CONFIG_HOME

# Warm the filesystem cache. Exit 2 (violations found) is the expected outcome on
# a lint corpus, so the exit code is ignored.
"$BIN" "$CORPUS" >/dev/null 2>&1 || true

best=$(perl -MTime::HiRes=time -e '
  my ($bin, $corpus, $runs) = @ARGV;
  my $best = 9**9;
  for (1 .. $runs) {
    my $t0 = time;
    system("\"$bin\" \"$corpus\" >/dev/null 2>&1");
    my $ms = (time - $t0) * 1000;
    $best = $ms if $ms < $best;
  }
  printf "%.1f", $best;
' "$BIN" "$CORPUS" "$RUNS")

echo "bench: corpus best of $RUNS runs: ${best} ms (budget ${BUDGET_MS} ms)"
awk -v got="$best" -v budget="$BUDGET_MS" 'BEGIN { exit !(got + 0 <= budget + 0) }' || {
  echo "FAIL: corpus lint took ${best} ms, over the ${BUDGET_MS} ms budget" >&2
  exit 1
}
