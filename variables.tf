variable "env" {
  description = "Deployment environment. Drives every name and the mandatory env tag."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod. A third environment is a platform decision, not a pipeline one."
  }
}

variable "domain" {
  description = "Tenant domain. A new domain is onboarded by the platform team, not declared ad hoc."
  type        = string

  validation {
    condition     = contains(["animal", "sensor", "clinical", "platform"], var.domain)
    error_message = "domain must be one of: animal, sensor, clinical, platform."
  }
}

variable "pipeline" {
  description = "Pipeline slug. Empty for domain- or platform-level resources that belong to no pipeline."
  type        = string
  default     = ""

  validation {
    condition     = var.pipeline == "" || can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.pipeline))
    error_message = "pipeline must be lowercase alphanumeric with hyphens, 3-32 chars, not starting or ending with a hyphen."
  }
}

variable "layer" {
  description = "Lakehouse layer. Empty for resources that sit outside the layer model."
  type        = string
  default     = ""

  validation {
    condition     = var.layer == "" || contains(["raw", "bronze", "silver", "gold", "mart", "science"], var.layer)
    error_message = "layer must be one of: raw, bronze, silver, gold, mart, science."
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
    condition     = contains(["terraform", "dectl", "manual"], var.managed_by)
    error_message = "managed_by must be terraform, dectl, or manual."
  }
}

variable "account_id" {
  description = "Account id, appended to globally-unique names. Passed in rather than read from a data source so the module stays testable with mock providers."
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
    condition = length(setintersection(
      keys(var.extra_tags),
      ["lakeworks:env", "lakeworks:domain", "lakeworks:pipeline", "lakeworks:layer", "lakeworks:owner", "lakeworks:managed-by"]
    )) == 0
    error_message = "extra_tags must not override a mandatory lakeworks: tag. Change the corresponding variable instead."
  }
}
