output "humanitec_metadata" {
  description = "Metadata for Humanitec."
  value = merge(
    {
      "Kubernetes-Namespace" = var.namespace
    },
    {
      for k, v in kubernetes_cron_job.default :
      "Kubernetes-CronJob-${k}" => v.metadata[0].name
    }
  )
}

output "cronjob_names" {
  description = "Map of schedule keys to CronJob names"
  value = {
    for k, v in kubernetes_cron_job.default : k => v.metadata[0].name
  }
}
