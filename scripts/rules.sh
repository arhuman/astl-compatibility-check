#!/bin/sh
# The rules astl implements, as an alternation for grep -E.
#
# Sourced by both regeneration scripts, so the two golden files cannot end up
# filtered by different lists. Keep it in step with rules.IDs in
# github.com/arhuman/ansible-static-lint.
#
# Callers anchor the end of the id with (\[|:) so "name" does not match
# "name-something". Rules ansible-lint ships as opt-in are listed even though a
# default run never emits them, so enabling one upstream needs no edit here.

RULES='avoid-implicit|command-instead-of-module|command-instead-of-shell'
RULES="$RULES|complexity|deprecated-bare-vars|deprecated-local-action"
RULES="$RULES|empty-string-compare|galaxy|galaxy-version-incorrect|ignore-errors"
RULES="$RULES|inline-env-var|jinja-template-extension|key-order|latest|literal-compare"
RULES="$RULES|loop-var-prefix|meta-incorrect|meta-no-tags|meta-runtime"
RULES="$RULES|meta-video-links|name|no-changed-when|no-free-form|no-handler"
RULES="$RULES|no-jinja-when|no-log-password|no-prompting|no-relative-paths|no-tabs"
RULES="$RULES|package-latest|partial-become|playbook-extension"
RULES="$RULES|risky-file-permissions|risky-octal|risky-shell-pipe|role-name"
RULES="$RULES|run-once|sanity|var-naming|yaml"
