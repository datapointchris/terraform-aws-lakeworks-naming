terraform {
  required_version = ">= 1.9"
}

# The single place a lakeworks name is constructed. Nothing else may concatenate one.
#
# AWS resource names take hyphens and anything SQL reads takes underscores. The README's grammar
# section gives the reason, and the glue_database output is where the underscores are built.

locals {
  prefix = "lakeworks-${var.env}"

  # Whether the call is pipeline- or layer-scoped. Every name and tag that depends on it reads
  # these rather than testing the input again.
  has_pipeline = var.pipeline != ""
  has_layer    = var.layer != ""

  # The 64-character IAM role ceiling is the tightest limit any name built on scope has to clear.
  scope = local.has_pipeline ? "${local.prefix}-${var.domain}-${var.pipeline}" : "${local.prefix}-${var.domain}"

  # Its keys are also the keys the extra_tags validation refuses.
  mandatory_tags = {
    "lakeworks:env"        = var.env
    "lakeworks:domain"     = var.domain
    "lakeworks:pipeline"   = local.has_pipeline ? var.pipeline : "none"
    "lakeworks:layer"      = local.has_layer ? var.layer : "none"
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
