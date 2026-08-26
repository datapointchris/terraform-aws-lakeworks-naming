# `terraform test` with no provider — this module creates nothing, so the tests are pure and fast.
# The point is that the naming standard becomes executable. A drift in the convention fails CI
# rather than being noticed in a review three months later.

variables {
  account_id = "123456789012"
}

run "builds_pipeline_scoped_names" {
  command = plan

  variables {
    env      = "prod"
    domain   = "animal"
    pipeline = "conform"
    layer    = "silver"
    owner    = "animal-team"
  }

  assert {
    condition     = output.glue_job == "lakeworks-prod-animal-conform-job"
    error_message = "Glue job name drifted from lakeworks-{env}-{domain}-{pipeline}-{resource}."
  }

  assert {
    condition     = output.state_machine == "lakeworks-prod-animal-conform-sfn"
    error_message = "State machine name drifted from the standard."
  }

  assert {
    condition     = output.glue_database == "lakeworks_prod_animal_silver"
    error_message = "Glue database must be underscored — a hyphen forces backtick-quoting in Athena and Spark."
  }

  assert {
    condition     = output.lake_bucket == "lakeworks-prod-lake-123456789012"
    error_message = "Lake bucket must carry the account suffix; S3 names are globally unique."
  }

  assert {
    condition     = output.warehouse_prefix == "warehouse/silver/animal"
    error_message = "Warehouse prefix drifted."
  }
}

run "domain_scoped_names_omit_the_pipeline_segment" {
  command = plan

  variables {
    env    = "dev"
    domain = "platform"
  }

  assert {
    condition     = output.scope == "lakeworks-dev-platform"
    error_message = "A resource with no pipeline must be domain-scoped, not carry an empty segment."
  }

  assert {
    condition     = output.glue_job == null
    error_message = "Pipeline-scoped names must be null when no pipeline is given, so a caller cannot use one by accident."
  }

  assert {
    condition     = output.alert_topic == "lakeworks-dev-platform-alerts"
    error_message = "Alert topics are per-domain."
  }

  assert {
    condition     = output.plan_role == "lakeworks-dev-platform-plan-role"
    error_message = "A plan role is domain-scoped, so it resolves without a pipeline."
  }
}

run "every_resource_carries_the_six_mandatory_tags" {
  command = plan

  variables {
    env      = "dev"
    domain   = "sensor"
    pipeline = "stream"
    layer    = "bronze"
    owner    = "sensor-team"
  }

  assert {
    condition = alltrue([
      for k in ["lakeworks:env", "lakeworks:domain", "lakeworks:pipeline",
      "lakeworks:layer", "lakeworks:owner", "lakeworks:managed-by"] :
      contains(keys(output.tags), k)
    ])
    error_message = "A mandatory tag is missing. Cost attribution and drift detection both depend on all six."
  }

  assert {
    condition     = output.tags["lakeworks:managed-by"] == "terraform"
    error_message = "managed_by must default to terraform; `manual` is the drift signal."
  }
}

run "unowned_and_unscoped_resources_say_so_rather_than_being_blank" {
  command = plan

  variables {
    env    = "dev"
    domain = "platform"
  }

  assert {
    condition     = output.tags["lakeworks:owner"] == "unowned"
    error_message = "An ownerless resource must be tagged `unowned`. A blank tag is invisible in a cost report; an explicit one is greppable."
  }

  assert {
    condition     = output.tags["lakeworks:pipeline"] == "none"
    error_message = "Pipeline tag must be `none`, not empty, for the same reason."
  }
}

run "rejects_a_domain_that_was_never_onboarded" {
  command = plan

  variables {
    env    = "dev"
    domain = "marketing"
  }

  expect_failures = [var.domain]
}

run "rejects_a_third_environment" {
  command = plan

  variables {
    env    = "staging"
    domain = "animal"
  }

  expect_failures = [var.env]
}

run "rejects_a_malformed_pipeline_slug" {
  command = plan

  variables {
    env      = "dev"
    domain   = "animal"
    pipeline = "Conform_Job"
  }

  expect_failures = [var.pipeline]
}

run "rejects_an_attempt_to_override_a_mandatory_tag" {
  command = plan

  variables {
    env        = "dev"
    domain     = "animal"
    extra_tags = { "lakeworks:owner" = "someone-else" }
  }

  expect_failures = [var.extra_tags]
}
