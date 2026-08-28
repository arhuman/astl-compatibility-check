# astl-compatibility-check

The compatibility contract for
[astl](https://github.com/arhuman/ansible-static-lint) against
[ansible-lint](https://github.com/ansible/ansible-lint).

It holds the reference corpus, the frozen ansible-lint output over that corpus,
and a single test that asserts astl reproduces it. astl claims its pep8 output
matches ansible-lint line for line; this repository is where that claim is
either true or a test failure.

## Why it is a separate repository

Verifying compatibility requires ansible-lint's own test data (the corpus and
the golden output), which is GPL-3.0-or-later. Vendoring it into
[github.com/arhuman/ansible-static-lint](https://github.com/arhuman/ansible-static-lint)
would put astl's MIT license in question, so the data and the harness live
here, under GPL-3.0-or-later, and neither file exists in astl's tree. That is
narrower than saying astl contains nothing from ansible-lint: it does, under
its default output mode, reproduce ansible-lint's diagnostic message strings
verbatim. See `NOTICE.md` for what that means and astl's ADR 0004 for the
reasoning and its limits.

## What is checked

| Path | Contents |
|---|---|
| `corpus/` | The ansible-lint `examples/` tree, 510 files |
| `golden/golden_pep8.txt` | ansible-lint 26.8.0 output over the corpus, filtered to the 38 rules astl implements: 2370 lines |
| `golden/expected_extra.txt` | The 48 findings astl emits beyond the golden, each one reviewed and explained in `PARITY.md` |
| `check_test.go` | The harness |

The assertion is an identity, not a threshold:

1. Every golden line must appear in astl's output. A missing line is a recall
   regression and fails the test individually.
2. The multiset of lines astl emits beyond the golden must equal
   `golden/expected_extra.txt` exactly. A new extra fails as a false positive.
   An expected extra that stopped appearing also fails: behaviour changed, and
   the file must be updated deliberately rather than drift.

`PARITY.md` documents the 48 extras, the four classes they fall into, and the
upstream quirks astl reproduces on purpose.

## Running

The harness needs an astl to run. On a fresh clone it installs the published
module and needs nothing else:

```sh
make check
```

A checkout of
[github.com/arhuman/ansible-static-lint](https://github.com/arhuman/ansible-static-lint)
takes precedence when one sits in the sibling directory
`../ansible-static-lint`, and that is the mode to use when working on astl
itself, because it is the only one that sees uncommitted changes:

```sh
git clone https://github.com/arhuman/ansible-static-lint ../ansible-static-lint
make check
```

`ASTL_REPO` points it at a checkout kept elsewhere, `ASTL_VERSION` selects
which published version the fallback installs:

```sh
make check ASTL_REPO=/path/to/ansible-static-lint
make check ASTL_REPO=/nonexistent ASTL_VERSION=v0.1.0
```

The two modes answer different questions. A checkout says whether the astl in
front of you is compatible; a version says whether a release was. Only the
second is reproducible after the fact, and only the first can fail before a
change is published, which is why CI clones astl rather than installing it.

## Updating

The contract is pinned to ansible-lint 26.8.0, and to the yamllint 1.38.0 and
ansible-core 2.21.3 that ship beneath it. All three pins, plus the corpus ref,
live in `scripts/upstream.sh`, which both regeneration scripts source. Edit that
one file, then rebuild **both** golden files:

```sh
make regenerate         # corpus/ and golden/golden_pep8.txt
make regenerate-cases   # golden/cases_pep8.txt
```

Both are needed: the two golden files are two contracts over the same upstream
version, and regenerating one without the other pins them to different
ansible-lints while every gate stays green.

`make regenerate` deliberately does not touch `golden/expected_extra.txt`: the
script prints the command that recomputes the candidate extras, and every line
of that output must be read and explained in `PARITY.md` before it is written to
the file. An unreviewed extra is a false positive shipped as a contract.

Both targets are reproducible: run them on an unchanged pin and the golden files
come back byte for byte identical, so any diff you see is a real change to
review. That holds because the scripts neutralize the two parts of the machine
that would otherwise leak in (the yamllint configuration and the resolved
ansible collections) and sort their output with `LC_ALL=C`. `PARITY.md` records
what each of those was hiding.

## License

GPL-3.0-or-later, see `LICENSE` and `NOTICE.md`.
