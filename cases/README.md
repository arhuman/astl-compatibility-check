# cases/

Fixtures this project wrote, for behaviour the upstream corpus never exercises.

`corpus/` is ansible-lint's own `examples/` tree at the pinned release, and
passing it is not the same as being compatible: it covers what upstream chose to
test, which is not the same set as what astl can get wrong. Every fixture here
is a divergence that was found some other way, confirmed against ansible-lint by
hand, fixed, and then written down so the gate catches the next one.

They live outside `corpus/` because `make regenerate` deletes that directory and
refills it from the upstream tree, and because its contents are ansible-lint's
test data while these are not.

## The contract

`golden/cases_pep8.txt` is the output of the pinned ansible-lint over this
directory, filtered to the rules astl implements. `TestRegressionCases` asserts
astl reproduces it **exactly**, with no allowance for extra findings: unlike the
corpus contract, a fixture is added here because the two are supposed to agree
on it completely. An extra means astl is wrong, or the fixture is exercising
something its author did not intend.

Regenerate with `make regenerate-cases` after adding a fixture, and read the
diff: the golden file is a claim about what ansible-lint does, so a line that
appears without your understanding why is a line you cannot vouch for.

## What is here

| Fixture | Divergence it pins |
| ------- | ------------------ |
| `yaml11-booleans.yml` | `create: no` on a `lineinfile`. ansible parses YAML 1.1 through PyYAML, where `no` is False; the parser astl uses implements YAML 1.2, where it is the string `"no"`, which is non-empty and so truthy. astl reported a `risky-file-permissions` upstream does not. The file also pins the cases that must **not** change: bare `false` and `off`, quoted `"no"` (a string, so truthy), and bare `YES`. |
| `yaml11-booleans.yml`, second play | The same mismatch on the rendering side rather than the reading side. A message interpolates the whole loop value, so a bare `no` inside a list goes through the container path; ansible-lint prints Python's `False` where astl quoted the word. |
| `roles/yaml11tags/` | The same mismatch reaching a different rule in the opposite direction. A `galaxy_tags` entry written as bare `no` carries the `!!str` tag, so astl saw a valid string tag and stayed silent, while ansible-lint reports `Tags must be strings: 'False'`. |
