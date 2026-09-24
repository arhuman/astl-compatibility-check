# Changelog

<!-- Succinct and public-facing: what changed, not why or how it was decided. -->

All notable changes to this project are documented here. Format:
[Keep a Changelog](https://keepachangelog.com). Entries are grouped under
`[Unreleased]` by date, using Added / Changed / Fixed / Removed.

## [Unreleased]

### Changed - 2026-09-24

- The reviewed extras go from 48 to 55: astl's new `no-free-form` rule reaches
  two files ansible-lint abandons before linting them, `block.yml` (an
  `import_tasks` of a file that does not exist) and `nomatches.yml` (an
  `ansible.builtin.action` that resolves to no installed module). Both were
  already documented divergence classes in PARITY.md; no new class appears.


- The golden output now carries `no-free-form`, which the rule filter left out:
  `golden/golden_pep8.txt` goes from 2387 to 2417 lines, the 30 new ones all
  findings of that rule. The corpus already held upstream's fixtures for it, so
  only the filter in `scripts/rules.sh` changed; `corpus/` and the 48 expected
  extras are untouched. astl does not implement the rule yet, so the corpus
  check fails on those 30 lines until it does. That is the point: the contract
  leads the implementation rather than following it.

### Added - 2026-09-23

- `make bench-compare`: reproduces the astl vs ansible-lint numbers astl's
  README publishes. It builds astl, installs the pinned upstream toolchain in a
  throwaway venv and times cold start, a single playbook, the corpus and max RSS
  under hyperfine. `make bench` stays the one-sided CI guard; this target is the
  comparison, which nothing could previously reproduce.

No version has been tagged. What follows is the initial public release: the
compatibility contract between
[astl](https://github.com/arhuman/ansible-static-lint) and ansible-lint 26.8.0.

### Added - 2026-08-21

Two contracts, each a frozen ansible-lint output plus the assertion over it:
the corpus contract, over upstream's own test tree, and the cases contract,
over fixtures written here.

- The corpus contract: `corpus/`, the ansible-lint 26.8.0 `examples/` tree, with
  `golden/golden_pep8.txt` (2370 lines of pinned ansible-lint output, filtered
  to the rules astl implements) and `golden/expected_extra.txt` (the 46 findings
  astl emits beyond the golden, hand-reviewed, never regenerated).
- The cases contract: `cases/`, this project's own fixtures for behaviour the
  upstream corpus does not exercise, with `golden/cases_pep8.txt` and no
  tolerance for extras. The first two pin YAML 1.1 boolean handling:
  `create: no` on a `lineinfile`, and a `galaxy_tags` entry written as bare
  `no`.
- `check_test.go`, asserting both contracts as an identity rather than a
  threshold. A missing golden line, a new extra, and an expected extra that
  stopped appearing each fail individually.
- Two ways to resolve astl: a checkout at `ASTL_REPO` (default
  `../ansible-static-lint`), the only mode that sees unreleased changes, or an
  install of `cmd/astl@$ASTL_VERSION` so a lone clone of this repository still
  runs. CI clones astl.
- `make regenerate` and `make regenerate-cases`, rebuilding each golden file
  from the toolchain pinned in `scripts/upstream.sh` (ansible-lint 26.8.0,
  yamllint 1.38.0, ansible-core 2.21.3). Both are reproducible: an unchanged pin
  returns byte-identical output. Neither touches `expected_extra.txt`.
- `make bench`, a wall-clock regression guard over the corpus with the budget in
  `BENCH_BUDGET_MS`.
- `make check`, `make cover`, and `make audit` (coverage gate, `go mod verify`,
  golangci-lint, govulncheck), run by CI on every push and pull request
  alongside a Conventional Commits gate.
- `PARITY.md`, the parity report: the single root cause behind all 46 extras
  (ansible-lint abandons a file whose syntax check fails, astl has no ansible
  runtime and lints it anyway), the four classes it splits into, the emulated
  upstream quirks, and the remaining yamllint-config limits.
- `NOTICE.md`, the provenance and licensing of the vendored ansible-lint test
  data, which is why this harness is a separate GPL-3.0-or-later repository.
