# Notice

## Provenance

`corpus/` and `golden/golden_pep8.txt` derive from ansible-lint:

- Upstream: https://github.com/ansible/ansible-lint
- License: GPL-3.0-or-later
- Version: 26.8.0

`corpus/` is a copy of the upstream `examples/` tree, with symlinks
dereferenced. `golden/golden_pep8.txt` is the output of ansible-lint 26.8.0
run over that tree, filtered to the 38 rules astl implements, with paths
rewritten to the `corpus/` prefix. Both are derivative works of ansible-lint.

## License of this repository

This repository is licensed GPL-3.0-or-later, the same license as its upstream
source. The full text is in `LICENSE`, copied verbatim from the ansible-lint
`COPYING` file.

## Relationship with ansible-static-lint

astl, the linter this repository checks, is
[github.com/arhuman/ansible-static-lint](https://github.com/arhuman/ansible-static-lint).
It is a separate work, licensed MIT. It
contains none of the corpus or golden test data described above: no corpus
file, no golden output. The GPL obligations created by that data stop at the
boundary of this repository.

That is not the same as saying astl contains nothing derived from
ansible-lint. Under its default output mode (`--ids upstream`), each finding
astl reports reproduces ansible-lint's diagnostic message string verbatim,
embedded as a short string literal in astl's own Go source, for example
"Commands should not change things if nothing needs doing." That text is
copied character for character from ansible-lint's source. ADR 0004, in the
[ansible-static-lint repository](https://github.com/arhuman/ansible-static-lint),
records why these specific strings are kept,
and `--ids native` demonstrates that an original replacement exists for every
one of them.

This repository builds astl from source and runs it as a subprocess. It does
not link against it, embed it, or redistribute it.
