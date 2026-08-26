output "tags" {
  description = "The six mandatory tags plus any extras. Applied at the provider's default_tags so a resource cannot forget them."
  value       = merge(local.mandatory_tags, var.extra_tags)
}

output "prefix" {
  description = "Environment prefix, for names this module does not construct."
  value       = local.prefix
}

output "scope" {
  description = "Environment + domain + pipeline, the stem every resource name shares."
  value       = local.scope
}

# ---------- lake and operations storage ----------

output "lake_bucket" {
  description = "The lakehouse bucket. Account-suffixed because S3 names are globally unique."
  value       = "${local.prefix}-lake-${var.account_id}"
}

output "ops_bucket" {
  description = "Artifacts, logs, query results, plan JSON. Split from the lake so one policy can be strict and the other permissive."
  value       = "${local.prefix}-ops-${var.account_id}"
}

output "raw_prefix" {
  description = "Where an ingestion job lands bytes. Iceberg never writes here."
  value       = var.pipeline == "" ? null : "raw/${var.domain}/${var.pipeline}"
}

output "warehouse_prefix" {
  description = "Iceberg-managed. Nothing outside a Spark or PyIceberg commit writes under this."
  value       = var.layer == "" ? null : "warehouse/${var.layer}/${var.domain}"
}

# ---------- catalog ----------

output "glue_database" {
  description = "Underscored, because Athena and Spark both quote a hyphen forever."
  value       = var.layer == "" ? null : "lakeworks_${var.env}_${var.domain}_${var.layer}"
}

# ---------- compute and orchestration ----------

output "glue_job" {
  description = "Glue job name."
  value       = var.pipeline == "" ? null : "${local.scope}-job"
}

output "lambda_function" {
  value = var.pipeline == "" ? null : "${local.scope}-fn"
}

output "state_machine" {
  value = var.pipeline == "" ? null : "${local.scope}-sfn"
}

output "schedule" {
  value = var.pipeline == "" ? null : "${local.scope}-schedule"
}

output "log_group" {
  description = "Log group. Retention is set by the consuming module and is never left unset — CloudWatch ingestion is a real line item."
  value       = var.pipeline == "" ? null : "/lakeworks/${var.env}/${var.domain}/${var.pipeline}"
}

# ---------- identity ----------

output "task_role" {
  description = "The identity the job's own code assumes."
  value       = var.pipeline == "" ? null : "${local.scope}-task-role"
}

output "execution_role" {
  description = "The identity the service assumes to start the job, before your code runs."
  value       = var.pipeline == "" ? null : "${local.scope}-execution-role"
}

# ---------- messaging ----------

output "alert_topic" {
  description = "Per-domain, not per-pipeline. Sixteen SNS topics is sixteen subscriptions to maintain."
  value       = "${local.prefix}-${var.domain}-alerts"
}
