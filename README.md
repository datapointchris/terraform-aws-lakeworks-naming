# terraform-aws-lakeworks-naming

The one place a lakeworks name is built. This Terraform module creates no resources. It takes an
environment, a domain, a pipeline and a layer, and validates each one. It returns every AWS
resource name a lakeworks pipeline needs, and the tags every resource carries.

The modules that call it create the resources and own them. This module owns only the strings.
Nothing here stops a caller from concatenating a name by hand, so the standard holds only where
callers read their names from its outputs. Where they do, an input outside the standard fails the
plan, rather than surviving as a name until a review months later.

## Install

A caller sources the module from git and pins a tag.

```hcl
source = "git::https://github.com/datapointchris/terraform-aws-lakeworks-naming.git?ref=<tag>"
```

```bash
git ls-remote --tags --refs https://github.com/datapointchris/terraform-aws-lakeworks-naming.git  # the tags a caller can pin
```

The module is not on the Terraform Registry. A registry-style `source` with a `version` argument
does not resolve. The repo is named `terraform-aws-lakeworks-naming` because the Registry accepts
only the `terraform-<provider>-<name>` form. The name keeps publishing possible. Nothing has been
published.

An output added in a later tag reaches a caller only when that caller moves its pin.

The module declares no provider and reads no data source, so it needs no AWS credentials. It needs
a Terraform at least as recent as the `required_version` in `main.tf`.

## Starting from scratch

This prints every name for one pipeline, in an empty directory, with no AWS account behind it.

```bash
mkdir naming-demo && cd naming-demo   # an empty root module; nothing in it reaches AWS
url=https://github.com/datapointchris/terraform-aws-lakeworks-naming.git  # the module's repo
tag=$(git ls-remote --tags --refs --sort=-version:refname "$url" | head -n1 | cut -d/ -f3)  # the latest tag
cat > main.tf <<EOF                   # one module call, and an output that shows all of it
module "naming" {
  source = "git::${url}?ref=${tag}"

  env        = "dev"
  domain     = "animal"
  pipeline   = "conform"
  layer      = "silver"
  account_id = "123456789012" # any 12 digits; the module calls nothing
}

output "names" {
  value = module.naming
}
EOF
terraform init                        # clones the module at that tag; there is no provider to install
terraform plan                        # every name and tag, under "Changes to Outputs"
```

`plan` is the proof. It lists every output beside its value, and it has no resource to create.

Change `domain` to `marketing` and `plan` fails. The error names every domain the module accepts.

The module reads no data source, so the caller hands it the account id. A real caller passes
`data.aws_caller_identity.current.account_id`, as in the next section. A data source would need the
AWS provider. Without one, the module's tests run with no credentials.

## A resource takes its name from an output, and its tags from the provider

```hcl
data "aws_caller_identity" "current" {}

module "naming" {
  source = "git::https://github.com/datapointchris/terraform-aws-lakeworks-naming.git?ref=<tag>"

  env        = "prod"
  domain     = "animal"
  pipeline   = "conform"
  layer      = "silver"
  owner      = "animal-team"
  account_id = data.aws_caller_identity.current.account_id
}

provider "aws" {
  default_tags {
    tags = module.naming.tags # every resource this provider creates carries the mandatory tags
  }
}

resource "aws_glue_catalog_database" "silver" {
  name = module.naming.glue_database # lakeworks_prod_animal_silver
}

resource "aws_iam_role" "task" {
  name = module.naming.task_role # lakeworks-prod-animal-conform-task-role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_cloudwatch_log_group" "conform" {
  name              = module.naming.log_group # /lakeworks/prod/animal/conform
  retention_in_days = 30                      # the module names the group; the caller sets retention
}
```

Tags set at `default_tags` reach every resource, so no resource can leave them off.

The provider reads its tags from the module, and the module reads its account id through the
provider. That is not a cycle, because `tags` never reads `account_id`. A provider block that read
`lake_bucket`, which does, would be one.

## Three inputs are required, and a value outside the standard fails the plan

| Input | Default | Accepts | When empty |
| --- | --- | --- | --- |
| `env` | required | a closed list of environments | |
| `domain` | required | a closed list of onboarded domains | |
| `account_id` | required | exactly 12 digits | |
| `pipeline` | `""` | 3 to 32 lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit | names are domain-scoped, pipeline outputs are `null`, the tag reads `none` |
| `layer` | `""` | a closed list of lakehouse layers | layer outputs are `null`, the tag reads `none` |
| `owner` | `""` | any team slug | the tag reads `unowned` |
| `managed_by` | `terraform` | a closed list of what created the resource | |
| `extra_tags` | `{}` | any map that names no mandatory tag key | |

Each closed list lives in that input's `validation` block in `variables.tf`. A value outside it
fails at plan, and the error names every value the list accepts.

The lists are closed on purpose. Adding an environment or a domain is a decision about the
platform, made here, and never by one caller.

`managed_by = "manual"` marks a resource made by hand. That is the drift signal the tag exists to
carry.

## The grammar puts hyphens in AWS names and underscores in anything SQL reads

```text
scope              lakeworks-{env}-{domain}-{pipeline}, or lakeworks-{env}-{domain} with no pipeline
pipeline resource  {scope}-{suffix}                        job, fn, sfn, schedule
role               {scope}-{purpose}-role                  task, execution, plan
domain resource    lakeworks-{env}-{domain}-alerts
bucket             lakeworks-{env}-{purpose}-{account_id}  lake, ops
glue database      lakeworks_{env}_{domain}_{layer}
log group          /lakeworks/{env}/{domain}/{pipeline}
lake prefix        raw/{domain}/{pipeline}, warehouse/{layer}/{domain}
tag key            lakeworks:{dimension}                   env, domain, pipeline, layer, owner, managed-by
```

Each output carries one of these. The plan in "Starting from scratch" prints every output beside
its value.

Athena and Spark both make a hyphenated identifier need quoting in every query that names it. That
cost would recur on every query, so the Glue database name takes underscores. The AWS resource
names take hyphens.

A bucket name ends in the account id because an S3 bucket name is unique across every AWS account. The
lake and ops buckets are split so one can carry a strict policy and the other a permissive one.
The ops bucket holds artifacts, logs, query results and plan JSON.

The two lake prefixes keep raw bytes apart from Iceberg tables. An ingestion job lands bytes under
`raw/`. Only a Spark or PyIceberg commit writes under `warehouse/`.

The alert topic is per domain, not per pipeline. Every topic is a subscription somebody maintains.

`plan_role` is the read-only identity CI assumes to plan. It resolves with no pipeline, so a repo
covering a whole domain gets a domain-scoped role. Given a pipeline, it takes the pipeline segment
like the other roles.

## A pipeline output with no pipeline is `null`, never a name with a gap

Without `pipeline`, these outputs are `null`: `glue_job`, `lambda_function`, `state_machine`,
`schedule`, `task_role`, `execution_role`, `log_group` and `raw_prefix`. Without `layer`,
`glue_database` and `warehouse_prefix` are `null`. The rest always resolve: `prefix`, `scope`,
`lake_bucket`, `ops_bucket`, `plan_role`, `alert_topic` and `tags`.

Without the `null`, a call with no pipeline would return `lakeworks-dev-animal-sfn`. That looks
like a real name, and every pipeline-less call in the domain would get the same one. No output is
ever an empty string, for the same reason.

A `null` stops the plan wherever a name is required or interpolated. `aws_glue_job`,
`aws_lambda_function` and `aws_glue_catalog_database` require their name. A `null` inside a
`"${...}"` string is an error.

A `null` does not stop the plan where the AWS provider treats the name as optional. That covers
`aws_iam_role`, `aws_sfn_state_machine`, `aws_cloudwatch_log_group` and `aws_scheduler_schedule`.
There a `null` is the same as leaving the name out, and the provider generates one. A caller that
names one of those from a pipeline output has to pass `pipeline`.

## An absent tag value is named, never blank

```text
lakeworks:env         env
lakeworks:domain      domain
lakeworks:pipeline    pipeline, or none
lakeworks:layer       layer, or none
lakeworks:owner       owner, or unowned
lakeworks:managed-by  managed_by, which defaults to terraform
```

A blank tag is invisible in a cost report. An explicit `unowned` is searchable, and finding
unowned resources is the reason the tag exists.

`extra_tags` merge over this set. An extra tag that names one of these keys fails validation, so
the way to change a mandatory tag is its input.

## The 64-character role ceiling is a warning at plan, not a failure

IAM rejects a role name over 64 characters, several minutes into an apply. A `check` block in
`main.tf` measures `{scope}-execution-role`, the longest role name the grammar builds.

Terraform reports a failed `check` assertion as a warning. The plan still succeeds, and an apply
goes on to IAM's rejection. Read the plan's warnings before applying a pipeline with a long slug.

The pipeline validation alone does not keep a role under the ceiling. The fixed segments of
`lakeworks-prod-{domain}-{pipeline}-execution-role` take 31 characters. That leaves 33 for the
domain and the pipeline together in `prod`, and 34 in `dev`. A slug the validation accepts can
still overrun it.

## A change here changes the standard for every caller

```bash
terraform test   # every naming case, with no provider and no credentials, in under a second
```

Adding a domain or an environment, loosening a validation, or renaming an output decides what every
caller may name things. It is not a local edit.

The tests assert the generated names, the domain-scoped names and `null`s with no pipeline, and
every mandatory tag.
They also assert that each of these fails at plan: a domain never onboarded, a third environment, a
malformed pipeline slug, and an extra tag that overrides a mandatory key.

A change that adds a name or a validation adds its case to `tests/naming.tftest.hcl`. The failure
cases matter most. A validation nothing tests can be removed without anyone noticing.
