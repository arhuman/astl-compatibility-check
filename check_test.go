// Package check holds the compatibility harness that pins astl's output
// against frozen ansible-lint output over the vendored corpus.
package check

import (
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

const (
	goldenPath = "golden/golden_pep8.txt"
	extraPath  = "golden/expected_extra.txt"
	corpusDir  = "corpus"

	// Fixtures this project wrote, kept out of corpus/ because regenerate.sh
	// deletes that directory and refills it from upstream.
	casesGoldenPath = "golden/cases_pep8.txt"
	casesDir        = "cases"

	// Checkout of astl the harness builds from. ASTL_REPO overrides it.
	defaultLinter = "../ansible-static-lint"

	// Published package used when no checkout is present. ASTL_VERSION
	// overrides the version. "latest" is a placeholder: astl carries no tag
	// yet, and this route is reproducible only once the version is fixed.
	linterPkg      = "github.com/arhuman/ansible-static-lint/cmd/astl"
	defaultVersion = "latest"
)

// TestRegressionCases asserts astl reproduces golden/cases_pep8.txt over cases/
// exactly, with no allowance for extra findings.
//
// A fixture lands in cases/ precisely because astl and ansible-lint are meant to
// agree on it, so an extra means astl is wrong or the fixture tests something its
// author did not intend. Each one is a divergence found by hand and written down
// so the next regression fails the gate instead of going unnoticed.
func TestRegressionCases(t *testing.T) {
	got := runLinter(t, buildLinter(t), casesDir)
	golden := sortedLines(readFile(t, casesGoldenPath))

	missing, extra := diff(got, golden)
	t.Logf("matched %d of %d case lines", len(golden)-len(missing), len(golden))

	for _, l := range missing {
		t.Errorf("missing case line: %s", l)
	}
	for _, l := range extra {
		t.Errorf("finding not produced by ansible-lint over %s: %s", casesDir, l)
	}
}

// TestCompatibility asserts astl's output over corpus/ in both directions: every
// golden line must be reproduced, and the findings astl emits beyond the golden
// must equal golden/expected_extra.txt.
//
// astl covers a different slice of ansible-lint's rules than a full run, so a
// reviewed set of extras is expected. A new extra is a regression; a vanished one
// means behaviour changed and the file must be updated deliberately.
func TestCompatibility(t *testing.T) {
	got := runLinter(t, buildLinter(t), corpusDir)
	golden := sortedLines(readFile(t, goldenPath))
	expectedExtra := sortedLines(readFile(t, extraPath))

	missing, extra := diff(got, golden)
	t.Logf("matched %d of %d golden lines (%d extra, %d expected)",
		len(golden)-len(missing), len(golden), len(extra), len(expectedExtra))

	for _, l := range missing {
		t.Errorf("missing golden line: %s", l)
	}

	vanished, unexpected := diff(extra, expectedExtra)
	for _, l := range unexpected {
		t.Errorf("new extra finding, not in %s: %s", extraPath, l)
	}
	for _, l := range vanished {
		t.Errorf("expected extra no longer emitted, update %s: %s", extraPath, l)
	}
}

// buildLinter returns the path to an astl binary, built from a checkout at
// ASTL_REPO or at the sibling ../ansible-static-lint, and installed from the
// module proxy when neither exists.
//
// The checkout wins because it is the only route that sees uncommitted changes,
// which is when a parity break is worth catching, and it is how astl's own CI
// drives this repository. The proxy fallback lets a fresh clone of this
// repository run the contract without cloning astl first.
func buildLinter(t *testing.T) string {
	t.Helper()
	repo := os.Getenv("ASTL_REPO")
	if repo == "" {
		repo = defaultLinter
	}
	repo, err := filepath.Abs(repo)
	if err != nil {
		t.Fatalf("resolve ASTL_REPO: %v", err)
	}
	if _, err := os.Stat(filepath.Join(repo, "go.mod")); err != nil {
		t.Logf("no checkout of astl at %s, falling back to the published module", repo)
		return installLinter(t)
	}

	bin := filepath.Join(t.TempDir(), "astl")
	build := exec.Command("go", "build", "-o", bin, "./cmd/astl")
	build.Dir = repo
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build astl: %v\n%s", err, out)
	}
	return bin
}

// installLinter fetches astl from the module proxy and returns the binary. GOBIN
// points into the test's temporary directory so a run cannot overwrite the astl
// a developer keeps on their PATH.
func installLinter(t *testing.T) string {
	t.Helper()
	version := os.Getenv("ASTL_VERSION")
	if version == "" {
		version = defaultVersion
	}

	gobin := t.TempDir()
	install := exec.Command("go", "install", linterPkg+"@"+version)
	install.Env = append(os.Environ(), "GOBIN="+gobin)
	if out, err := install.CombinedOutput(); err != nil {
		t.Fatalf("install %s@%s: %v\n%s\n"+
			"the harness needs astl either as a checkout beside this repository "+
			"(git clone https://github.com/arhuman/ansible-static-lint ../ansible-static-lint, "+
			"or ASTL_REPO=<path>) or as a published module reachable from the proxy",
			linterPkg, version, err, out)
	}
	return filepath.Join(gobin, "astl")
}

// runLinter runs bin over dir from this repository's root, where the golden
// paths are anchored, and returns its output lines sorted.
func runLinter(t *testing.T, bin, dir string) []string {
	t.Helper()
	cmd := exec.Command(bin, dir)
	cmd.Env = hermeticEnv(t)
	out, err := cmd.Output()
	if err != nil {
		// Exit 2 is "violations found", 3 adds "a file could not be read". The
		// corpus ships deliberately broken fixtures, so 3 is expected here.
		ee, ok := err.(*exec.ExitError)
		if !ok || (ee.ExitCode() != 2 && ee.ExitCode() != 3) {
			t.Fatalf("run astl: %v", err)
		}
	}
	return sortedLines(string(out))
}

// hermeticEnv returns the parent environment with the machine's own yamllint
// configuration removed: the golden file was produced on yamllint's bundled
// defaults, so a developer carrying a config of their own would see the yaml
// findings shift and read it as a parity break in astl. XDG_CONFIG_HOME points
// at an empty directory rather than being unset, because unsetting it falls back
// to ~/.config instead of disabling the lookup.
func hermeticEnv(t *testing.T) []string {
	t.Helper()
	env := make([]string, 0, len(os.Environ())+1)
	for _, kv := range os.Environ() {
		switch {
		case strings.HasPrefix(kv, "YAMLLINT_CONFIG_FILE="),
			strings.HasPrefix(kv, "XDG_CONFIG_HOME="):
		default:
			env = append(env, kv)
		}
	}
	return append(env, "XDG_CONFIG_HOME="+t.TempDir())
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(data)
}

func sortedLines(s string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if strings.TrimSpace(l) != "" {
			out = append(out, l)
		}
	}
	sort.Strings(out)
	return out
}

// diff compares two sorted lists counting duplicates: missing holds the want
// lines got does not cover, extra the got lines want does not account for.
func diff(got, want []string) (missing, extra []string) {
	count := map[string]int{}
	for _, l := range got {
		count[l]++
	}
	for _, l := range want {
		if count[l] > 0 {
			count[l]--
			continue
		}
		missing = append(missing, l)
	}
	for l, n := range count {
		for i := 0; i < n; i++ {
			extra = append(extra, l)
		}
	}
	sort.Strings(extra)
	return missing, extra
}
