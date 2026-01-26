variable "metadata" {
  type        = any
  description = "The metadata section of the Score file."
}

variable "containers" {
  type = map(object({
    image     = string
    command   = optional(list(string))
    args      = optional(list(string))
    variables = optional(map(string))
    files = optional(map(object({
      source        = optional(string)
      content       = optional(string)
      binaryContent = optional(string)
      mode          = optional(string)
      noExpand      = optional(bool)
    })))
    volumes = optional(map(object({
      source   = string
      path     = optional(string)
      readOnly = optional(bool)
    })))
    resources = optional(object({
      limits = optional(object({
        memory = optional(string)
        cpu    = optional(string)
      }))
      requests = optional(object({
        memory = optional(string)
        cpu    = optional(string)
      }))
    }))
  }))
  description = "The containers section of the Score file."
}

variable "schedules" {
  type = map(object({
    schedule = string
    container_overrides = optional(map(object({
      command = optional(list(string))
      args    = optional(list(string))
    })))
  }))
  description = "Map of schedules. Each schedule creates a separate CronJob resource."

  validation {
    condition     = length(var.schedules) > 0
    error_message = "At least one schedule must be defined."
  }
}

variable "cronjob_spec" {
  type = object({
    concurrency_policy            = optional(string)
    failed_jobs_history_limit     = optional(number)
    successful_jobs_history_limit = optional(number)
    starting_deadline_seconds     = optional(number)
    suspend                       = optional(bool)
  })
  description = "CronJob-specific configuration."
  default     = {}
}

variable "job_spec" {
  type = object({
    backoff_limit              = optional(number)
    ttl_seconds_after_finished = optional(number)
    active_deadline_seconds    = optional(number)
    completions                = optional(number)
    parallelism                = optional(number)
  })
  description = "Job-specific configuration."
  default     = {}
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to deploy the resources into."
}

variable "service_account_name" {
  type        = string
  description = "The name of the service account to use for the pods."
  default     = null
}

variable "additional_annotations" {
  type        = map(string)
  description = "Additional annotations to add to all resources."
  default     = {}
}
