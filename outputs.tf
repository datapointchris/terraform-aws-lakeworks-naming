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
  value       = local.has_pipeline ? "raw/${var.domain}/${var.pipeline}" : null
}

output "warehouse_prefix" {
  description = "Iceberg-managed. Nothing outside a Spark or PyIceberg commit writes under this."
  value       = local.has_layer ? "warehouse/${var.layer}/${var.domain}" : null
}

# ---------- catalog ----------

output "glue_database" {
  description = "Underscored, because Athena and Spark both quote a hyphen forever."
  value       = local.has_layer ? "lakeworks_${var.env}_${var.domain}_${var.layer}" : null
}

# ---------- compute and orchestration ----------

output "glue_job" {
  description = "Glue job name."
  value       = local.has_pipeline ? "${local.scope}-job" : null
}

output "lambda_function" {
  value = local.has_pipeline ? "${local.scope}-fn" : null
}

output "state_machine" {
  value = local.has_pipeline ? "${local.scope}-sfn" : null
}

output "schedule" {
  value = local.has_pipeline ? "${local.scope}-schedule" : null
}

output "log_group" {
  description = "Log group. Retention is set by the consuming module and is never left unset — CloudWatch ingestion is a real line item."
  value       = local.has_pipeline ? "/lakeworks/${var.env}/${var.domain}/${var.pipeline}" : null
}

# ---------- identity ----------

output "task_role" {
  description = "The identity the job's own code assumes."
  value       = lookup(local.role_names, "task", null)
}

output "execution_role" {
  description = "The identity the service assumes to start the job, before your code runs."
  value       = lookup(local.role_names, "execution", null)
}

output "plan_role" {
  description = "The read-only identity CI assumes to plan against this account. Resolves without a pipeline, so a repo covering a whole domain gets a domain-scoped role. Given a pipeline, it takes the pipeline segment like the other roles."
  value       = local.role_names["plan"]
}

# ---------- messaging ----------

output "alert_topic" {
  description = "Per-domain, not per-pipeline. Sixteen SNS topics is sixteen subscriptions to maintain."
  value       = "${local.prefix}-${var.domain}-alerts"
}
