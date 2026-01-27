resource "random_id" "id" {
  byte_length = 8
}

locals {
  # Extract schedules from either var.schedules or var.metadata.schedules (v1 compatibility)
  schedules = coalesce(
    var.schedules,
    try(var.metadata.schedules, null),
    {}
  )

  # Debug: Force error if schedules are empty to see what metadata contains
  debug_check = length(local.schedules) > 0 ? "ok" : "ERROR: No schedules found. Metadata keys: ${jsonencode(keys(var.metadata))}, Metadata schedules: ${jsonencode(try(var.metadata.schedules, "NOT_FOUND"))}"

  # Extract v1 extension specs from metadata (for backward compatibility with v1 humanitec.score.yaml)
  metadata_cronjob_spec = try(var.metadata.cronjob, {})
  metadata_job_spec     = try(var.metadata.job, {})
  metadata_pod_spec     = try(var.metadata.pod, {})

  # Merge cronjob spec from both sources (module inputs take precedence)
  merged_cronjob_spec = {
    concurrency_policy            = try(var.cronjob_spec.concurrency_policy, local.metadata_cronjob_spec.concurrencyPolicy, null)
    failed_jobs_history_limit     = try(var.cronjob_spec.failed_jobs_history_limit, local.metadata_cronjob_spec.failedJobsHistoryLimit, null)
    successful_jobs_history_limit = try(var.cronjob_spec.successful_jobs_history_limit, local.metadata_cronjob_spec.successfulJobsHistoryLimit, null)
    starting_deadline_seconds     = try(var.cronjob_spec.starting_deadline_seconds, local.metadata_cronjob_spec.startingDeadlineSeconds, null)
    suspend                       = try(var.cronjob_spec.suspend, local.metadata_cronjob_spec.suspend, null)
    time_zone                     = try(var.cronjob_spec.time_zone, local.metadata_cronjob_spec.timeZone, null)
  }

  # Merge job spec from both sources
  merged_job_spec = {
    backoff_limit              = try(var.job_spec.backoff_limit, local.metadata_job_spec.backoffLimit, null)
    ttl_seconds_after_finished = try(var.job_spec.ttl_seconds_after_finished, local.metadata_job_spec.ttlSecondsAfterFinished, null)
    active_deadline_seconds    = try(var.job_spec.active_deadline_seconds, local.metadata_job_spec.activeDeadlineSeconds, null)
    completions                = try(var.job_spec.completions, local.metadata_job_spec.completions, null)
    parallelism                = try(var.job_spec.parallelism, local.metadata_job_spec.parallelism, null)
  }

  # Merge pod spec from both sources
  merged_pod_spec = {
    node_selector = try(var.pod_spec.node_selector, local.metadata_pod_spec.nodeSelector, null)
    os_name       = try(var.pod_spec.os_name, local.metadata_pod_spec.os.name, null)
  }

  # Base labels with app identifier
  base_pod_labels = { app = random_id.id.hex }

  # Merge labels for different resource types (including v1 metadata sources)
  cronjob_labels = merge(
    local.base_pod_labels,
    try(local.metadata_cronjob_spec.labels, {}),
    var.cronjob_labels
  )

  job_labels = merge(
    local.base_pod_labels,
    try(local.metadata_job_spec.labels, {}),
    var.job_labels
  )

  pod_labels = merge(
    local.base_pod_labels,
    try(local.metadata_pod_spec.labels, {}),
    var.pod_labels
  )

  # Create a map of all secret data, keyed by a stable identifier
  all_secret_data = merge(
    { for k, v in kubernetes_secret.env : "env-${k}" => v.data },
    { for k, v in kubernetes_secret.files : "file-${k}" => v.data }
  )

  # Create a sorted list of the keys of the combined secret data
  sorted_secret_keys = sort(keys(local.all_secret_data))

  # Create a stable JSON string from the secret data by using the sorted keys
  stable_secret_json = jsonencode([
    for key in local.sorted_secret_keys : {
      key  = key
      data = local.all_secret_data[key]
    }
  ])

  # Merge annotations for different resource types (including v1 metadata sources)
  cronjob_annotations = merge(
    coalesce(try(var.metadata.annotations, null), {}),
    var.additional_annotations,
    try(local.metadata_cronjob_spec.annotations, {}),
    var.cronjob_annotations,
    { "checksum/config" = nonsensitive(sha256(local.stable_secret_json)) }
  )

  job_annotations = merge(
    var.additional_annotations,
    try(local.metadata_job_spec.annotations, {}),
    var.job_annotations
  )

  pod_annotations = merge(
    coalesce(try(var.metadata.annotations, null), {}),
    var.additional_annotations,
    try(local.metadata_pod_spec.annotations, {}),
    var.pod_annotations,
    { "checksum/config" = nonsensitive(sha256(local.stable_secret_json)) }
  )

  # Flatten files from all containers into a map for easier iteration.
  # We only care about files with inline content for creating secrets.
  all_files_with_content = {
    for pair in flatten([
      for ckey, cval in var.containers : [
        for fkey, fval in coalesce(cval.files, {}) : {
          ckey      = ckey
          fkey      = fkey
          is_binary = lookup(fval, "binaryContent", null) != null
          data      = coalesce(lookup(fval, "binaryContent", null), lookup(fval, "content", null))
        } if lookup(fval, "content", null) != null || lookup(fval, "binaryContent", null) != null
      ] if cval != null
    ]) : "${pair.ckey}-${substr(sha256(pair.fkey), 0, 10)}" => pair
  }

  # Flatten all external volumes from all containers into a single map,
  # assuming volume mount paths are unique across the pod.
  all_volumes = {
    for pair in flatten([
      for ckey, cval in var.containers : [
        for vkey, vval in coalesce(cval.volumes, {}) : {
          ckey  = ckey
          vkey  = vkey
          value = vval
        }
      ] if cval != null
    ]) : "${pair.ckey}-${pair.vkey}" => pair.value
  }

  # For each schedule, create a merged container map with overrides applied
  schedule_containers = {
    for schedule_key, schedule_val in local.schedules : schedule_key => {
      for container_key, container_val in var.containers : container_key => merge(
        container_val,
        {
          # Support both v1 style (containers.main-container.args) and v2 style (container_overrides.main-container.args)
          command = try(
            schedule_val.container_overrides[container_key].command,
            schedule_val.containers[container_key].command,
            container_val.command
          )
          args = try(
            schedule_val.container_overrides[container_key].args,
            schedule_val.containers[container_key].args,
            container_val.args
          )
        }
      )
    }
  }
}


resource "kubernetes_secret" "env" {
  for_each = nonsensitive(toset([for k, v in var.containers : k if v.variables != null]))

  metadata {
    name        = "${var.metadata.name}-${each.value}-env"
    namespace   = var.namespace
    annotations = var.additional_annotations
  }

  data = var.containers[each.value].variables
}

resource "kubernetes_secret" "files" {
  for_each = nonsensitive(toset(keys(local.all_files_with_content)))

  metadata {
    name        = "${var.metadata.name}-${each.value}"
    namespace   = var.namespace
    annotations = var.additional_annotations
  }

  data = {
    for k, v in { content = local.all_files_with_content[each.value].data } : k => v if !local.all_files_with_content[each.value].is_binary
  }

  binary_data = {
    for k, v in { content = local.all_files_with_content[each.value].data } : k => v if local.all_files_with_content[each.value].is_binary
  }
}

resource "kubernetes_cron_job" "default" {
  for_each = local.schedules

  metadata {
    name        = "${var.metadata.name}-${each.key}"
    namespace   = var.namespace
    labels      = local.cronjob_labels
    annotations = local.cronjob_annotations
  }

  spec {
    schedule                      = each.value.schedule
    concurrency_policy            = local.merged_cronjob_spec.concurrency_policy
    failed_jobs_history_limit     = coalesce(local.merged_cronjob_spec.failed_jobs_history_limit, 1)
    successful_jobs_history_limit = coalesce(local.merged_cronjob_spec.successful_jobs_history_limit, 3)
    starting_deadline_seconds     = local.merged_cronjob_spec.starting_deadline_seconds
    suspend                       = coalesce(local.merged_cronjob_spec.suspend, false)
    # Note: time_zone requires Kubernetes 1.25+ and Terraform Kubernetes provider 2.16+
    # Uncomment if your cluster and provider support it:
    # time_zone                     = local.merged_cronjob_spec.time_zone

    job_template {
      metadata {
        labels      = local.job_labels
        annotations = local.job_annotations
      }

      spec {
        backoff_limit              = local.merged_job_spec.backoff_limit
        ttl_seconds_after_finished = local.merged_job_spec.ttl_seconds_after_finished
        active_deadline_seconds    = local.merged_job_spec.active_deadline_seconds
        completions                = local.merged_job_spec.completions
        parallelism                = local.merged_job_spec.parallelism

        template {
          metadata {
            annotations = local.pod_annotations
            labels      = local.pod_labels
          }

          spec {
            restart_policy       = "OnFailure"
            service_account_name = var.service_account_name
            node_selector        = local.merged_pod_spec.node_selector

            security_context {
              run_as_non_root = true
              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            dynamic "os" {
              for_each = local.merged_pod_spec.os_name != null ? [1] : []
              content {
                name = local.merged_pod_spec.os_name
              }
            }

            dynamic "container" {
              for_each = local.schedule_containers[each.key]
              iterator = container
              content {
                name    = container.key
                image   = container.value.image
                command = container.value.command
                args    = container.value.args

                dynamic "env_from" {
                  for_each = container.value.variables != null ? [1] : []
                  content {
                    secret_ref {
                      name = kubernetes_secret.env[container.key].metadata[0].name
                    }
                  }
                }

                security_context {
                  allow_privilege_escalation = false
                }

                resources {
                  limits = {
                    cpu    = try(container.value.resources.limits.cpu, null)
                    memory = try(container.value.resources.limits.memory, null)
                  }
                  requests = {
                    cpu    = try(container.value.resources.requests.cpu, null)
                    memory = try(container.value.resources.requests.memory, null)
                  }
                }

                dynamic "volume_mount" {
                  for_each = { for k, v in local.all_files_with_content : k => v if v.ckey == container.key }
                  iterator = file
                  content {
                    name       = "file-${file.key}"
                    mount_path = dirname(file.value.fkey)
                    read_only  = true
                  }
                }

                dynamic "volume_mount" {
                  for_each = coalesce(container.value.volumes, {})
                  iterator = volume
                  content {
                    name       = "volume-${volume.key}"
                    mount_path = volume.key
                    read_only  = coalesce(volume.value.readOnly, false)
                  }
                }
              }
            }

            dynamic "volume" {
              for_each = local.all_files_with_content
              iterator = file
              content {
                name = "file-${file.key}"
                secret {
                  secret_name = kubernetes_secret.files[file.key].metadata[0].name
                  items {
                    key  = "content"
                    path = basename(file.value.fkey)
                  }
                }
              }
            }

            dynamic "volume" {
              for_each = local.all_volumes
              iterator = volume
              content {
                name = "volume-${volume.key}"
                persistent_volume_claim {
                  claim_name = volume.value.source
                }
              }
            }
          }
        }
      }
    }
  }
}
