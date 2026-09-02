# CLAUDE.md

Guidance for Claude Code working in this repository.

Read the README first. It carries the grammar, why hyphens and underscores are split the way they
are, the two calling behaviours that surprise people, and the 64-character ceiling.

## This module is the naming standard, executed

It creates nothing. It takes the components, validates them, and returns names and tags. Its whole
value is that the convention fails CI instead of being noticed in a review months later.

So a change here is a change to the standard for every consumer. Adding a permitted domain or
environment, loosening a validation, or renaming an output is not a local edit — it is a decision
about what the platform is allowed to name things.

## Consumers pin by git tag

```hcl
source = "git::https://github.com/datapointchris/terraform-aws-lakeworks-naming.git?ref=v0.2.0"
```

The module is not published to the Terraform Registry, so a registry-style `source` plus `version`
does not resolve. The repo is named `terraform-aws-lakeworks-naming` because the Registry parses
`terraform-{provider}-{name}` and only that form can ever be published — the name buys the option,
it does not mean the option was taken.

An output added in a new tag reaches a consumer only when that consumer bumps its pin. Check what
pins exist before assuming a new output is available everywhere.

## Never make an output blank

Pipeline-scoped outputs return `null` when no pipeline is given, so a missing argument fails loudly
at the consuming resource rather than producing `lakeworks-dev-animal--sfn`. Do not substitute an
empty string to make an interpolation tidier.

The inverse holds for tags. An absent value is named — `unowned`, `none` — never blank. A blank tag
is invisible in a cost report, and finding unowned resources is the entire point of the tag.

## The ceiling is asserted, not documented

IAM rejects a role name over 64 characters several minutes into an apply. A `check` block asserts
the generated role name fits so the failure lands at plan time. The longest name this grammar
produces is 57 characters, which is seven of headroom — a longer pipeline slug or a new segment
eats it fast.

Any change that lengthens a name should be checked against that assertion rather than eyeballed.

## Tests

```bash
terraform test
```

Eight cases, no provider, no AWS, sub-second. They assert the generated names, assert all six
mandatory tags are present, and assert that an unknown domain, a third environment, a malformed
pipeline slug and an attempt to override a mandatory tag each fail at plan time.

A new name or a new validation gets a case in the same change. The failure cases matter more than
the success ones — a validation nothing tests is one that can be silently removed.
