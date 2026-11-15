# The closed lists. Each validation below checks its input against one of these and names the same
# list in its error, so a value added here is accepted and named in one edit.
locals {
  accepted_envs       = ["dev", "prod"]
  accepted_domains    = ["animal", "sensor", "clinical", "platform"]
  accepted_layers     = ["raw", "bronze", "silver", "gold", "mart", "science"]
  accepted_managed_by = ["terraform", "dectl", "manual"]
}

variable "env" {
  description = "Deployment environment. Drives every name and the mandatory env tag."
  type        = string

  validation {
    condition     = contains(local.accepted_envs, var.env)
    error_message = "env must be one of: ${join(", ", local.accepted_envs)}. A third environment is a platform decision, not a pipeline one."
  }
}

variable "domain" {
  description = "Tenant domain. A new domain is onboarded by the platform team, not declared ad hoc."
  type        = string

  validation {
    condition     = contains(local.accepted_domains, var.domain)
    error_message = "domain must be one of: ${join(", ", local.accepted_domains)}."
  }
}

variable "pipeline" {
  description = "Pipeline slug. Empty for domain- or platform-level resources that belong to no pipeline."
  type        = string
  default     = ""

  validation {
    condition     = var.pipeline == "" || can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.pipeline))
    error_message = "pipeline must be 3-32 lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "layer" {
  description = "Lakehouse layer. Empty for resources that sit outside the layer model."
  type        = string
  default     = ""

  validation {
    condition     = var.layer == "" || contains(local.accepted_layers, var.layer)
    error_message = "layer must be one of: ${join(", ", local.accepted_layers)}."
  }
}

variable "owner" {
  description = "Owning team slug, surfaced as a tag so an unowned resource is visibly unowned."
  type        = string
  default     = ""
}

variable "managed_by" {
  description = "What created this. `manual` is a drift signal that a scheduled query counts."
  type        = string
  default     = "terraform"

  validation {
    condition     = contains(local.accepted_managed_by, var.managed_by)
    error_message = "managed_by must be one of: ${join(", ", local.accepted_managed_by)}."
  }
}

variable "account_id" {
  description = "Account id, appended to globally-unique names. Passed in rather than read from a data source, so the module needs no provider and its tests run without credentials."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "extra_tags" {
  description = "Additional tags merged over the mandatory set. Cannot override a mandatory key."
  type        = map(string)
  default     = {}

  validation {
    condition = length(setintersection(keys(var.extra_tags), keys(local.mandatory_tags))) == 0
    # A mandatory key lakeworks:<dimension> is set from the input of the same name, with hyphens
    # as underscores, so the message derives the input from the key.
    error_message = join(" ", [
      for key in sort(setintersection(keys(var.extra_tags), keys(local.mandatory_tags))) :
      "extra_tags sets ${key}, which the module sets from the ${replace(trimprefix(key, "lakeworks:"), "-", "_")} input. Remove it from extra_tags and set ${replace(trimprefix(key, "lakeworks:"), "-", "_")} instead."
    ])
  }
}
