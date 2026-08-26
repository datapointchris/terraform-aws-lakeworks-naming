# terraform-aws-lakeworks-naming

The single place a `lakeworks` name is constructed. Nothing else in the department may concatenate
one.

A naming standard written only in prose is a naming standard with drift. This module takes the
components, validates them against the allowed environment and domain lists, and returns every name
a pipeline needs. A caller cannot build a name another way, because this module is the only thing
that receives the account id.

## Usage

```hcl
module "naming" {
  source  = "datapointchris/naming/aws-lakeworks"
  version = "~> 0.1"

  env        = "prod"
  domain     = "animal"
  pipeline   = "conform"
  layer      = "silver"
  owner      = "animal-team"
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_glue_catalog_database" "silver" {
  name = module.naming.glue_database   # lakeworks_prod_animal_silver
}

resource "aws_sfn_state_machine" "conform" {
  name     = module.naming.state_machine   # lakeworks-prod-animal-conform-sfn
  tags     = module.naming.tags            # the six mandatory tags
  role_arn = aws_iam_role.conform.arn
}
```

## The grammar

```text
resource:  lakeworks-{env}-{domain}-{pipeline}-{resource}
glue db:   lakeworks_{env}_{domain}_{layer}
iam role:  lakeworks-{env}-{domain}-{pipeline}-{purpose}-role
tag key:   lakeworks:{dimension}
```

Hyphens for AWS resource names, underscores for anything SQL touches. That split is not aesthetic —
Athena and Spark both make a hyphenated identifier require backtick-quoting forever, and that cost
is paid on every query rather than once here.

## Two behaviours worth knowing before you call it

**Pipeline-scoped outputs are `null` when no pipeline is given.** A caller that omits `pipeline`
gets `null` from `glue_job`, `state_machine` and the rest, rather than a name with an empty segment.
That turns a missing argument into a loud failure at the consuming resource instead of a resource
called `lakeworks-dev-animal--sfn`.

**Absent values are named, not blank.** An ownerless resource is tagged `lakeworks:owner = unowned`
and a pipeline-less one gets `lakeworks:pipeline = none`. A blank tag is invisible in a cost report;
an explicit one is greppable, and finding unowned resources is the point of having the tag.

## The 64-character ceiling

IAM rejects a role name over 64 characters, several minutes into an apply. A `check` block asserts
the generated role name fits, so the failure lands at plan time instead.

The longest name this grammar produces is
`lakeworks-prod-platform-observability-step-functions-role` at 57 characters. Seven characters of
headroom, so a pipeline slug has room to grow but not much.

## Tests

```bash
terraform test
```

Eight cases, no provider, no AWS, sub-second. The module creates nothing, so the tests are pure —
they assert the generated names, assert all six mandatory tags are present, and assert that an
unknown domain, a third environment, a malformed pipeline slug and an attempt to override a
mandatory tag each fail at plan time.

That is the point of the module existing at all: the naming standard is executable, so a drift in
the convention fails CI rather than being noticed in a review three months later.
