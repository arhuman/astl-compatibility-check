# Parity report

Reference: `ansible-lint 26.8.0 -f pep8` over `corpus/`, filtered to the 38
rules astl implements, frozen as `golden/golden_pep8.txt` (2370 lines), with
yamllint 1.38.0 and ansible-core 2.21.3 beneath it. All four pins live in
`scripts/upstream.sh`.

`make regenerate` reproduces that file byte for byte. Getting there took two
fixes worth recording, because both were cases of the environment leaking into
the contract:

- **Collections.** `risky-file-permissions` reports on the modules it can
  resolve, so a machine with `community.general` installed produced 14 findings
  where a bare ansible-core produces 3. `ANSIBLE_HOME` is now redirected to an
  empty directory during regeneration. `--offline` was not enough: it stops
  galaxy fetching, not resolution of what is already on disk. An earlier
  revision of this file worked around the instability by appending the yaml[*]
  and var-naming lines to a frozen 2294-line base instead of regenerating; that
  workaround is gone and the file is now a single generated artifact.
- **Ordering.** ansible-lint's output order is not stable, so a regeneration
  that changed nothing still produced a large diff. The golden is now sorted
  with `LC_ALL=C`, which is also the order `check_test.go` compares in. Ordering
  carries no contract either way, since both sides are sorted before comparison.

Reproduce with `make check`.

## Result

| Metric | Count |
|---|---|
| Golden lines | 2370 |
| Matched | 2370 (100%) |
| Missing | 0 |
| Extra (false positives) | 48 |

astl emits 2418 lines: every golden line, plus the 48 findings ansible-lint
does not report. Those 48 are pinned line for line in
`golden/expected_extra.txt`, and the harness fails if the set changes in either
direction.

Five of the 38 rules are opt-in upstream (`empty-string-compare`,
`galaxy-version-incorrect`, `jinja-template-extension`, `no-log-password`,
`no-prompting`) and one, `loop-var-prefix`, is inert until `loop_var_prefix` is
set. astl keeps all six off by default for the same reason, so they contribute
no line to either side of this comparison. `ignore-errors` and
`playbook-extension` are on by default but the corpus holds nothing that trips
them.

## What the corpus does not cover

Passing `corpus/` is not the same as being compatible. It is ansible-lint's own
`examples/` tree, so it covers what upstream chose to test, which is a different
set from what a reimplementation can get wrong. Divergences found by other means
are pinned in `cases/`, with golden output from the same pinned ansible-lint in
`golden/cases_pep8.txt`.

That contract admits no extras. A fixture lands there because astl and
ansible-lint are supposed to agree on it exactly, so an extra finding means astl
is wrong rather than that it implements a different slice of upstream.

| Fixture | Divergence | Direction |
|---|---|---|
| `yaml11-booleans.yml` | `create: no` on a `lineinfile`. ansible parses YAML 1.1 through PyYAML, where `no` is False; yaml.v3 implements YAML 1.2, where it is a non-empty string and so truthy. | False positive: astl reported a `risky-file-permissions` upstream does not. |
| `yaml11-booleans.yml` (second play) | The same mismatch rendered into message text: a bare `no` inside a `with_nested` list reaches `pyRepr`. | Wrong text: astl printed `'no'` where upstream prints `False`. |
| `roles/yaml11tags/` | A `galaxy_tags` entry written as bare `no` carries the `!!str` tag, so astl read it as a valid string tag. | False negative: upstream reports `Tags must be strings: 'False'`. |

Each was confirmed against ansible-lint 26.8.0 before being fixed, and the
corpus passed both before and after every one of them.

## Residual difference classes

All 48 extras share one cause: ansible-lint aborts a file entirely when
ansible's own loader or syntax check fails on it, and reports nothing else for
that file. astl has no ansible runtime, so it lints the file anyway. The
syntax-check subprocess, module argspec validation and collection resolution
are explicitly outside the port's scope.

| Class | Files | Extra lines | Why upstream reports nothing |
|---|---|---|---|
| Play or task references a module that cannot be resolved | `nomatches.yml`, `syntax-error-string.yml`, `mocked_dependency.yml`, `rule-fqcn-pass.yml`, `rule-risky-file-permissions-fail.yml`, `rule-no-tabs.yml` | 18 | The module (`ansible.builtin.action`, `x.y.z.w`, `community.general.ini_file`, `community.windows.win_lineinfile`, ...) is not installed, so `ModuleArgsParser` raises and the file is abandoned |
| Play references a role that does not exist | `norole.yml`, `norole2.yml`, `with-umlaut-ä.yml`, `multiline-bracketsmatchtest.yml`, `multiline-brackets-do-not-match-test.yml`, `rule-no-jinja-when-fail.yml` | 16 | Role resolution fails during syntax check |
| Play imports or includes a file ansible rejects | `block.yml`, `include.yml` | 11 | `import_tasks: does-not-exist.yml`, and a play whose only key is `include_tasks`; on `include.yml` this also hides a `var-naming[no-role-prefix]` on a role entry key |
| Task file under a directory containing a space | `playbooks/tasks/directory with spaces/main.yml` | 1 | Not collected by the upstream run |
| Playbook made only of `import_playbook` entries fails syntax check | `corpus/site.yml` | 2 | `ansible-playbook --syntax-check` exits 1 on it, so upstream abandons the file; astl 0010's fix (a playbook whose first play is an `import_playbook` is now linted) then emits the two `name[play]` lines upstream itself emits when the syntax check passes, verified on a fixture against 26.8.0 |

All paths are relative to `corpus/playbooks/`, except `corpus/site.yml`.

The three files the rule expansion added to the ratchet are each corroborated
by upstream's own test suite, which pins the count astl reproduces:
`rule-risky-file-permissions-fail.yml` is documented as 11 occurrences,
`rule-no-jinja-when-fail.yml` as 3, and `rule-no-tabs.yml` as lines 12, 15 and
15. In other words astl agrees with ansible-lint on what these files contain;
the two only disagree on whether a file that fails syntax check should still be
linted.

Closing these would require running `ansible-playbook --syntax-check` (or
reimplementing collection and role resolution), which is the boundary the port
deliberately does not cross.

### The same class measured outside the corpus

On debops/debops, astl reports `name[template]` on
`ansible/playbooks/scope.yml:17` and ansible-lint reports nothing at all. The
mechanism was isolated rather than assumed, with three fixtures
that differ only in whether the loader fails:

| Fixture | ansible-lint 26.8.0 |
|---|---|
| Templated task name, no loader failure | `name[template]` fires, same position and message as astl |
| Same name, plus `import_role: name: "{{ role }}"` | only `syntax-check[specific]`; the name finding is gone |
| Same, plus `# noqa syntax-check[specific]` (the debops shape) | **nothing at all**, exit 0 |

`NameRule.matchtask` opens with `if file and file.failed(): return results`, and
`Lintable.failed()` is true once the file carries any `syntax-check`,
`load-failure` or `internal-error` match. The noqa comment then removes the
syntax-check match itself, at report time, after it has already silenced every
other rule on the file. So a single noqa'd loader failure suppresses the whole
file's findings.

astl's rule is right: the first row shows the two agree byte for byte whenever
the loader succeeds. Matching upstream here would mean knowing that ansible
cannot resolve `{{ role }}` at lint time, which is role resolution, the
boundary above. This stays an intentional divergence, and astl's output is
arguably the more useful of the two: the name really is malformed.

## Deliberate emulations

Seven upstream behaviours are reproduced on purpose because the golden file
depends on them:

- **The stray `[/]` suffix.** ansible-lint's pep8 formatter feeds the tag
  through rich markup. A single-word subtag such as `[casing]` is consumed as a
  style name, leaking a literal `[/]` into the output; hyphenated subtags such
  as `[no-changelog]` are not. astl's `format.Tag` reproduces this exactly.
- **Column numbers only for data-anchored findings.** Rules that pass a YAML
  node to `create_matcherror` report `line:column`; rules that pass only a
  filename report line 1 with no column.
- **The `(warning)` suffix.** ansible-lint's default `warn_list` contains the
  `experimental` tag, so every `complexity` finding is a warning rather than an
  error and its pep8 line ends in ` (warning)`. `complexity` is the only rule
  in astl's set that this applies to.
- **`name[prefix]` is never emitted.** Upstream computes the `{stem} | ` prefix
  for non-main task files but only raises the subtag when the rule is enabled
  explicitly. astl computes the same prefix, strips it before the casing
  check, and never raises `name[prefix]`.
- **yaml[*] messages are Python-capitalized.** ansible-lint renders yamllint
  descriptions through `str.capitalize()`, which also lowercases interpolated
  values: a duplicated key `FOO` is reported as `"foo"`. astl reproduces the
  transformation, and the whole family carries a line but no column, sorted
  and deduplicated by message exactly as upstream's match key does (padded
  brackets yield one finding, not two).
- **var-naming reports task vars twice in tasks files.** Upstream's play-shaped
  pass and its task pass both see a bare task's `vars:`; only the second adds
  the ` (vars: k)` suffix. Suppression scopes differ per pass too: a noqa on
  the task silences only the task-pass finding, a `skip_ansible_lint` tag or a
  same-line noqa silences both, and yaml[*] ignores task-scoped suppressions
  entirely. astl mirrors each path.
- **A repository's own `.yamllint` is honoured**, layered over ansible-lint's
  bundled policy with yamllint's own merge semantics. The corpus carries no
  such file, so the golden cannot see this either way; it is verified instead
  against ansible-lint's own configuration loader on real repositories and on
  fixtures in astl's `internal/yamllint/testdata/config`. Two limits remain
  and are reported on stderr rather than passed over: `ignore` patterns are
  not applied, and five yamllint rules stay unimplemented (`quoted-strings`,
  `key-ordering`, `empty-values`, `float-values`, `document-end`), all of them
  off in every bundled policy.
