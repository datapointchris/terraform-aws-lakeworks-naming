# terraform-aws-lakeworks-naming

The README carries the grammar, why hyphens and underscores are split the way they are, the two
calling behaviors that surprise people, and the 64-character ceiling. This file says how to work
here and points at the README section for each mechanism.

## This module is the naming standard, executed

It creates nothing. It takes the components, validates them, and returns names and tags. Its whole
value is that the convention fails CI instead of being noticed in a review months later.

So a change here is a change to the standard for every consumer. Adding a permitted domain or
environment, loosening a validation, or renaming an output is not a local edit — it is a decision
about what the platform is allowed to name things.

## Consumers pin by git tag

README § "Install" gives the `source` string, the command that lists the tags, and why the module
is not on the Registry. An output added in a new tag reaches a consumer only when that consumer
bumps its pin, so check what pins exist before assuming a new output is available everywhere.

## Never make an output blank

Do not substitute an empty string for a `null` output to make an interpolation tidier, and never
leave a tag value blank. README § "A pipeline output with no pipeline is `null`, never a name with
a gap" and § "An absent tag value is named, never blank" give the reasons and which outputs are
`null`.

## Check a lengthened name against the ceiling

Any change that lengthens a name should be checked against the `check` block in `main.tf` rather
than eyeballed. README § "The 64-character role ceiling is a warning at plan, not a failure" says
what it measures and why a failure only warns.

## Tests

```bash
terraform test
```

README § "A change here changes the standard for every caller" lists what the runs assert. A new
name or a new validation gets a case in the same change.
