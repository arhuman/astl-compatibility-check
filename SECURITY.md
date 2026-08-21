# Security Policy

## Supported versions

This repository has not cut a release. Only `main` receives fixes.

| Version | Supported |
| ------- | --------- |
| `main` | yes |
| older | no |

## Reporting a vulnerability

Do not open a public issue for a security report.

Use GitHub's private vulnerability reporting on this repository
(Security -> Report a vulnerability), which opens a private advisory visible
only to the maintainers. Include a description and, where possible, a file that
reproduces the problem.

Expect an acknowledgement within a few days. Please allow time for a fix before
any public disclosure.

## Threat model

This is a test harness, not a shipped artifact. It builds
[astl](https://github.com/arhuman/ansible-static-lint) from a sibling checkout
and runs it over the committed corpus; it opens no sockets and reads nothing
outside the
two repositories. The corpus is upstream ansible-lint test data and astl
treats it as untrusted input (see astl's own SECURITY.md); a corpus file that
makes the harness itself misbehave is in scope here.
