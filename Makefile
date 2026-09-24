# Checkout of github.com/arhuman/ansible-static-lint the harness builds astl
# from. Cloned as a sibling by default; override to point elsewhere.
ASTL_REPO ?= ../ansible-static-lint

# Installed from the module proxy when ASTL_REPO holds no checkout, so this
# repository can be cloned and checked on its own. A checkout always wins: only
# it can test unreleased astl changes, which is why CI clones astl.
ASTL_VERSION ?= latest

# Wall-clock budget for linting corpus/, in milliseconds. ~5x the current time,
# so noise cannot trip it but a structural speed regression does. Never raise it
# to green a red run; find what made the corpus slow instead.
BENCH_BUDGET_MS ?= 150
BENCH_RUNS ?= 5

# Coverage floor. The module is test-only, so coverage is 0.0% over zero
# statements; raise this if non-test code ever appears.
COVER_MIN ?= 0

# Pinned tool versions: must match .github/workflows/ci.yml.
GOLANGCI_VERSION    ?= v2.13.1
GOVULNCHECK_VERSION ?= v1.1.4

.DEFAULT_GOAL := help
.PHONY: audit bench bench-compare check cover help regenerate regenerate-cases tidy tools

## audit: run quality control checks (mod verify, lint, vuln scan, coverage gate)
audit: cover
	@which golangci-lint > /dev/null || $(MAKE) tools
	@which govulncheck > /dev/null || $(MAKE) tools
	go mod verify
	golangci-lint run ./...
	govulncheck ./...

## bench: build astl and fail if linting corpus/ exceeds BENCH_BUDGET_MS
bench:
	@ASTL_VERSION=$(ASTL_VERSION) ./scripts/bench.sh "$(ASTL_REPO)" corpus $(BENCH_BUDGET_MS) $(BENCH_RUNS)

## bench-compare: reproduce the published astl vs ansible-lint numbers (needs hyperfine)
# Not a gate: bench above is the one-sided guard CI runs. This target exists so
# the comparison quoted in astl's README can be reproduced rather than trusted.
bench-compare:
	@./scripts/bench-compare.sh "$(ASTL_REPO)" corpus $(BENCH_RUNS)

## check: build astl and assert its output against the frozen golden files
# Covers both contracts: the upstream corpus and this project's own cases/.
# -count=1 because the harness shells out to `go build` on ASTL_REPO, so astl's
# sources are not part of Go's test cache key: without it a verdict computed
# against different astl source is returned as `ok (cached)`, and a local
# `make parity` can report success without having compared the working tree.
check:
	@ASTL_REPO=$(ASTL_REPO) ASTL_VERSION=$(ASTL_VERSION) go test -count=1 ./...

## cover: run the check with coverage and fail below COVER_MIN
cover:
	@ASTL_REPO=$(ASTL_REPO) ASTL_VERSION=$(ASTL_VERSION) go test -count=1 -covermode=atomic -coverprofile=coverage.out ./...
	@go tool cover -func=coverage.out | awk '/^total:/ {print "coverage: " $$3}'
	@total=$$(go tool cover -func=coverage.out | awk '/^total:/ {print $$3}' | tr -d '%'); \
	awk -v t="$$total" -v min="$(COVER_MIN)" 'BEGIN { if (t+0 < min+0) { printf "FAIL: coverage %.1f%% < %d%%\n", t, min; exit 1 } }'

## help: list available targets
help:
	@echo "Available targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'

## regenerate: rebuild corpus/ and golden/ from the pinned upstream release
regenerate:
	@./scripts/regenerate.sh

## regenerate-cases: rebuild golden/cases_pep8.txt from the pinned upstream release
# Separate from regenerate: that target deletes corpus/ and refills it from
# upstream, while cases/ is this project's own and must survive.
regenerate-cases:
	@./scripts/regenerate-cases.sh

## tidy: format Go code and tidy the module file
tidy:
	go fmt ./...
	go mod tidy

## tools: install pinned Go development tools
tools:
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_VERSION)
	go install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION)
