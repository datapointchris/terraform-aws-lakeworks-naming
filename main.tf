terraform {
  required_version = ">= 1.9"
}

# The single place a lakeworks name is constructed. Nothing else may concatenate one.
#
# Two separators, deliberately: hyphens for AWS resource names, underscores for anything SQL
# touches. A hyphenated identifier forces backtick-quoting in Athena and Spark forever, and that
# cost is paid on every query rather than once here.

locals {
  prefix = "lakeworks-${var.env}"

  # Pipeline-scoped when a pipeline is given, domain-scoped otherwise. Both stay under the 64-char
  # ceiling that IAM roles impose, which is the tightest limit any of these names has to clear.
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
# Catching it at plan time costs nothing and is the difference between a fast failure and a slow one.
check "names_fit_aws_limits" {
  assert {
    condition     = length("${local.scope}-execution-role") <= 64
    error_message = "Generated IAM role name exceeds 64 characters: ${local.scope}-execution-role. Shorten the pipeline slug."
  }
}
