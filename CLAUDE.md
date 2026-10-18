# terraform-aws-lakeworks-naming

The README carries the grammar, why hyphens and underscores are split the way they are, the two
calling behaviors that surprise people, and the 64-character ceiling.

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

Pipeline-scoped outputs return `null` when no pipeline is given. Without the `null`, a call with no
pipeline would return `lakeworks-dev-animal-sfn`, a plausible name every pipeline-less call in the
domain would share. Do not substitute an empty string to make an interpolation tidier.

A `null` stops a caller's plan only where the name is required or interpolated: `aws_glue_job`,
`aws_lambda_function`, `aws_glue_catalog_database`, or any `"${...}"` string. Where the AWS provider
treats the name as optional, as on `aws_iam_role` and `aws_sfn_state_machine`, a `null` is the same
as no name and the provider generates one.

The inverse holds for tags. An absent value is named — `unowned`, `none` — never blank. A blank tag
is invisible in a cost report, and finding unowned resources is the entire point of the tag.

## The ceiling is a plan warning, not a plan failure

IAM rejects a role name over 64 characters several minutes into an apply. A `check` block measures
`{scope}-execution-role`, the longest role name the grammar builds. Terraform reports a failed
`check` as a warning, so the plan still succeeds and an apply goes on to IAM's rejection.

The pipeline validation alone does not keep a role under the ceiling. The fixed segments of
`lakeworks-prod-{domain}-{pipeline}-execution-role` take 31 characters, which leaves 33 for the
domain and the pipeline together. A slug the validation accepts can overrun it.

Any change that lengthens a name should be checked against that assertion rather than eyeballed.

## Tests

```bash
terraform test
```

No provider, no AWS, sub-second. The runs assert the generated names, assert all six mandatory tags
are present, and assert that an unknown domain, a third environment, a malformed pipeline slug and
an attempt to override a mandatory tag each fail at plan time. One run gives a valid slug long
enough to overrun the role ceiling and asserts the `check` trips.

A new name or a new validation gets a case in the same change. The failure cases matter more than
the success ones — a validation nothing tests is one that can be silently removed.
