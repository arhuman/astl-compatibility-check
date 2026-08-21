# Contributing

This repository is the compatibility contract for
[astl](https://github.com/arhuman/ansible-static-lint): the frozen ansible-lint
corpus, the golden output over it, and the harness asserting astl reproduces
that output. Most changes here are consequences of a change in
github.com/arhuman/ansible-static-lint or of moving to a newer upstream
ansible-lint release.

## Setup

Contributing here means changing what the harness asserts, so clone astl beside
this repository. That is the mode where the gate sees your uncommitted astl
changes, which is the only useful one while a parity break is being fixed:

```sh
git clone https://github.com/arhuman/astl-compatibility-check
git clone https://github.com/arhuman/ansible-static-lint
cd astl-compatibility-check
make check
```

Set `ASTL_REPO` if astl lives elsewhere. Without a checkout the harness falls
back to installing the published module at `ASTL_VERSION`, which is enough to
read the contract but cannot validate a fix that is not released yet.

## Make targets

| Target | Purpose |
| ------ | ------- |
| `make check` | Build astl and assert its output against the frozen golden files. |
| `make cover` | `check` with coverage; fails below `COVER_MIN`. |
| `make audit` | Coverage gate + `go mod verify` + `golangci-lint` + `govulncheck`. The same command runs in CI. |
| `make bench` | Speed regression guard: the corpus must lint under `BENCH_BUDGET_MS` (best of `BENCH_RUNS`). |
| `make regenerate` | Rebuild `corpus/` and `golden/golden_pep8.txt` from the pinned upstream release. |
| `make regenerate-cases` | Rebuild `golden/cases_pep8.txt` after adding or changing a fixture in `cases/`. Run it alongside `make regenerate` when moving upstream versions, since both goldens must come from the same pins in `scripts/upstream.sh`. |
| `make tidy` | `go fmt` + `go mod tidy`. |
| `make tools` | Install the pinned golangci-lint and govulncheck. |

## The contract

`golden/expected_extra.txt` is reviewed by hand, never regenerated blindly.
Every line astl emits beyond the golden must be read and explained in
`PARITY.md` before it enters the file; an unreviewed extra is a false positive
shipped as a contract. `make regenerate` deliberately refuses to touch it.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/):
`type(scope): subject`, with type one of
`feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`.
Checked in CI on pull requests.

## Before opening a pull request

1. `make audit` passes.
2. New or changed extras are explained in `PARITY.md`.
3. `CHANGELOG.md` has an entry under `[Unreleased]` if the contract changed.
