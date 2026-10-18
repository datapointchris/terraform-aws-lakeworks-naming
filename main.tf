terraform {
  required_version = ">= 1.9"
}

# The single place a lakeworks name is constructed. Nothing else may concatenate one.
#
# Two separators, deliberately: hyphens for AWS resource names, underscores for anything SQL
# touches. A hyphenated identifier has to be quoted in every query that names it: in backticks in
# Spark and in Athena DDL, and in double quotes in an Athena SELECT.

locals {
  prefix = "lakeworks-${var.env}"

  # Pipeline-scoped when a pipeline is given, domain-scoped otherwise. The 64-character ceiling on
  # IAM role names is the tightest limit any name built on it has to clear.
  scope = var.pipeline == "" ? "${local.prefix}-${var.domain}" : "${local.prefix}-${var.domain}-${var.pipeline}"

  mandatory_tags = {
    "lakeworks:env"        = var.env
    "lakeworks:domain"     = var.domain
    "lakeworks:pipeline"   = var.pipeline == "" ? "none" : var.pipeline
    "lakeworks:layer"      = var.layer == "" ? "none" : var.layer
    "lakeworks:owner"      = var.owner == "" ? "unowned" : var.owner
    "lakeworks:managed-by" = var.managed_by
  }
}

# An IAM role name over 64 characters is rejected by AWS at apply time, several minutes into a run.
# The pipeline validation alone cannot prevent it. A failed check is a plan warning, not a plan
# failure, so it surfaces the overrun before the apply without stopping it.
check "names_fit_aws_limits" {
  assert {
    condition     = length("${local.scope}-execution-role") <= 64
    error_message = "Generated IAM role name exceeds 64 characters: ${local.scope}-execution-role. Shorten the pipeline slug."
  }
}
