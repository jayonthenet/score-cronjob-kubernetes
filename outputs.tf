output "humanitec_metadata" {
  description = "Metadata for Humanitec."
  value = merge(
    {
      "Kubernetes-Namespace" = var.namespace
    },
    {
      for k, v in kubernetes_cron_job_v1.default :
      "Kubernetes-CronJob-${k}" => v.metadata[0].name
    }
  )
}

output "cronjob_names" {
  description = "Map of schedule keys to CronJob names"
  value = {
    for k, v in kubernetes_cron_job_v1.default : k => v.metadata[0].name
  }
}

output "debug_metadata_keys" {
  description = "Debug: Keys in metadata object"
  value       = keys(var.metadata)
}

output "debug_schedules_value" {
  description = "Debug: Value of metadata.schedules"
  value       = try(var.metadata.schedules, "NOT_FOUND")
}

output "debug_schedules_extracted" {
  description = "Debug: Extracted schedules from local"
  value       = local.schedules
}

output "debug_metadata_cronjob_spec" {
  description = "Debug: Extracted cronjob spec from metadata"
  value       = local.metadata_cronjob_spec
}

output "debug_merged_cronjob_spec" {
  description = "Debug: Merged cronjob spec"
  value       = local.merged_cronjob_spec
}

output "debug_merged_job_spec" {
  description = "Debug: Merged job spec"
  value       = local.merged_job_spec
}

output "debug_merged_pod_spec" {
  description = "Debug: Merged pod spec"
  value       = local.merged_pod_spec
}
