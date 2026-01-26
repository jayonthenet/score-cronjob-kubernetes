# score-cronjob-kubernetes

This is a Terraform / OpenTofu compatible module to be used to provision `score-cronjob` resources on top of Kubernetes for the Humanitec Orchestrator.

## Requirements

1. There must be a module provider setup for `kubernetes` (`hashicorp/kubernetes`).
2. There must be a resource type setup for `score-cronjob`, for example:

    ```shell
    hctl create resource-type score-cronjob --set=description='Score CronJob Workload'
    ```

## Installation

Install this with the `hctl` CLI, you should replace the `CHANGEME` in the module source with the latest release tag, replace the `CHANGEME` in the [provider mapping](https://developer.humanitec.com/platform-orchestrator/docs/configure/modules/overview/#provider-mapping) with your real provider type and alias for Kubernetes; and replace the `CHANGEME` in module inputs with the real target namespace.

```shell
hctl create module \
    --set=resource_type=score-cronjob \
    --set=module_source=git::https://github.com/humanitec-tf-modules/score-cronjob-kubernetes?ref=CHANGEME \
    --set=provider_mapping='{"kubernetes": "CHANGEME"}' \
    --set=module_params='{"metadata":{"type":"map"},"containers":{"type":"map"},"schedules":{"type":"map"}}' \
    --set=module_inputs='{"namespace": "CHANGEME"}'
```

### Using the Humanitec Terraform Provider

Alternatively, you can use the [Humanitec Terraform Provider](https://registry.terraform.io/providers/humanitec/humanitec/latest/docs) to manage this module configuration:

```hcl
# Configure the Humanitec provider
terraform {
  required_providers {
    humanitec = {
      source  = "humanitec/humanitec"
      version = "~> 1.0"
    }
  }
}

provider "humanitec" {
  # Set via HUMANITEC_TOKEN environment variable
  # or use the 'token' parameter
}

# Create the resource type (if not already exists)
resource "humanitec_resource_type" "score_cronjob" {
  id          = "score-cronjob"
  name        = "score-cronjob"
  description = "Score CronJob Workload"
}

# Define the module for score-cronjob resources
resource "humanitec_resource_definition" "score_cronjob_kubernetes" {
  id          = "score-cronjob-kubernetes"
  name        = "score-cronjob-kubernetes"
  type        = humanitec_resource_type.score_cronjob.id
  driver_type = "humanitec/terraform"

  driver_inputs = {
    values_string = jsonencode({
      # Module source - replace CHANGEME with the version tag
      source = "git::https://github.com/humanitec-tf-modules/score-cronjob-kubernetes?ref=CHANGEME"

      # Provider mapping - replace CHANGEME with your Kubernetes provider
      provider = {
        kubernetes = "CHANGEME"
      }

      # Module inputs - configure namespace and other settings
      variables = {
        namespace = "default"  # Replace with your namespace or use dynamic reference
        # Optional: service_account_name = "my-service-account"
        # Optional: additional_annotations = { "example.com/annotation" = "value" }
      }
    })
  }

  # Criteria to match this module to specific environments or applications
  # Remove this block to match all resources of this type
  provision = {
    "app.terraform.io/env/#id" = "$${context.env.id}"
  }
}

# Example: Define with dynamic namespace from k8s-namespace resource
resource "humanitec_resource_definition" "score_cronjob_with_dynamic_namespace" {
  id          = "score-cronjob-kubernetes-dynamic-ns"
  name        = "score-cronjob-kubernetes-dynamic-ns"
  type        = humanitec_resource_type.score_cronjob.id
  driver_type = "humanitec/terraform"

  driver_inputs = {
    values_string = jsonencode({
      source = "git::https://github.com/humanitec-tf-modules/score-cronjob-kubernetes?ref=CHANGEME"

      provider = {
        kubernetes = "CHANGEME"
      }

      variables = {
        # Reference the namespace from a k8s-namespace resource
        namespace = "$${resources.ns.outputs.name}"
      }
    })

    # Declare dependency on k8s-namespace resource
    secret_refs = jsonencode({
      ns = {
        type = "k8s-namespace"
      }
    })
  }

  provision = {
    "app.terraform.io/env/#id" = "$${context.env.id}"
  }
}

# Example: Configure CronJob and Job specifications
resource "humanitec_resource_definition" "score_cronjob_with_config" {
  id          = "score-cronjob-kubernetes-configured"
  name        = "score-cronjob-kubernetes-configured"
  type        = humanitec_resource_type.score_cronjob.id
  driver_type = "humanitec/terraform"

  driver_inputs = {
    values_string = jsonencode({
      source = "git::https://github.com/humanitec-tf-modules/score-cronjob-kubernetes?ref=CHANGEME"

      provider = {
        kubernetes = "CHANGEME"
      }

      variables = {
        namespace           = "production"
        service_account_name = "cronjob-sa"

        # Configure CronJob behavior
        cronjob_spec = {
          concurrency_policy            = "Forbid"
          failed_jobs_history_limit     = 3
          successful_jobs_history_limit = 5
          suspend                       = false
        }

        # Configure Job behavior
        job_spec = {
          backoff_limit              = 3
          ttl_seconds_after_finished = 3600  # Clean up after 1 hour
        }

        # Add custom annotations
        additional_annotations = {
          "monitoring.example.com/enabled" = "true"
        }
      }
    })
  }

  provision = {
    "app.terraform.io/env/#id" = "$${context.env.id}"
  }
}
```

The Terraform provider approach offers several advantages:

- **Version control**: Manage your Humanitec configuration as code
- **Modularity**: Reuse configurations across environments
- **Validation**: Terraform validates your configuration before applying
- **State management**: Track changes to your resource definitions over time

For more information on using the Humanitec Terraform Provider, see the [official documentation](https://registry.terraform.io/providers/humanitec/humanitec/latest/docs).

## Parameters

The module is designed to pass the `metadata`, `containers`, and `schedules` as parameters from the source score file, with any other module [inputs](#inputs) set by the platform engineer.

The required parameters are:
- `metadata` - Score metadata including the workload name
- `containers` - Container definitions (image, command, args, variables, files, volumes, resources)
- `schedules` - Map of schedules where each schedule creates a separate CronJob resource

The only required input that must be set by the `module_inputs` is the `namespace` which provides the target Kubernetes namespace.

For example, to set the `namespace` and `service_account_name`, you would use:

```shell
hctl create module \
    ...
    --set=module_inputs='{"namespace": "my-namespace", "service_account_name": "my-sa"}'
```

### Dynamic namespaces

Instead of a hardcoded destination namespace, you can use the resource graph to provision a namespace.

1. Ensure there is a resource type for the namespace (eg: `k8s-namespace`) and that there is a module and rule set up for it in the target environments.
2. Add a dependency to the create module request:

    ```
    --set=dependencies='{"ns": {"type": "k8s-namespace"}}'
    ```

3. In the module inputs replace this with the placeholder:

    ```
    --set=module_inputs='{"namespace": "${ resources.ns.outputs.name }"}'
    ```

## Schedules

The module supports multiple schedules per workload. Each schedule creates a separate CronJob resource in Kubernetes.

### Basic Schedule Example

```yaml
schedules:
  daily:
    schedule: "0 2 * * *"  # Run at 2 AM daily
```

This creates a CronJob named `{workload-name}-daily` that runs at 2 AM every day.

### Multiple Schedules with Command Overrides

You can define multiple schedules and override the command/args for each schedule:

```yaml
schedules:
  hourly:
    schedule: "0 * * * *"
    container_overrides:
      main:
        args: ["--type=hourly"]
  daily:
    schedule: "0 8 * * *"
    container_overrides:
      main:
        args: ["--type=daily"]
  weekly:
    schedule: "0 8 * * 1"
    container_overrides:
      main:
        args: ["--type=weekly"]
```

This creates three CronJob resources:
- `{workload-name}-hourly` - Runs every hour
- `{workload-name}-daily` - Runs at 8 AM daily
- `{workload-name}-weekly` - Runs at 8 AM every Monday

## CronJob Configuration

You can configure CronJob-specific behavior using `cronjob_spec` input:

```shell
--set=module_inputs='{
  "namespace": "production",
  "cronjob_spec": {
    "concurrency_policy": "Forbid",
    "failed_jobs_history_limit": 3,
    "successful_jobs_history_limit": 5
  }
}'
```

Available `cronjob_spec` options:
- `concurrency_policy` - How to handle concurrent executions: `Allow`, `Forbid`, or `Replace`
- `failed_jobs_history_limit` - Number of failed job pods to keep (default: 1)
- `successful_jobs_history_limit` - Number of successful job pods to keep (default: 3)
- `starting_deadline_seconds` - Deadline in seconds for starting a job if it misses its schedule
- `suspend` - Whether to suspend the CronJob (default: false)

## Job Configuration

You can configure Job-specific behavior using `job_spec` input:

```shell
--set=module_inputs='{
  "namespace": "production",
  "job_spec": {
    "backoff_limit": 3,
    "ttl_seconds_after_finished": 3600
  }
}'
```

Available `job_spec` options:
- `backoff_limit` - Number of retries before considering a job failed (default: 6)
- `ttl_seconds_after_finished` - Time in seconds after which a finished job is automatically deleted
- `active_deadline_seconds` - Maximum duration in seconds for a job to run
- `completions` - Number of successful completions required
- `parallelism` - Maximum number of pods running in parallel

## Examples

### Example 1: Daily Cleanup Job

```yaml
metadata:
  name: cleanup-job

containers:
  main:
    image: my-app:latest
    command: ["node"]
    args: ["cleanup.js"]
    variables:
      DATABASE_URL: "postgres://..."
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"

schedules:
  daily:
    schedule: "0 2 * * *"
```

### Example 2: Multiple Report Schedules

```yaml
metadata:
  name: report-generator

containers:
  main:
    image: report-generator:v2
    command: ["python"]
    args: ["generate_report.py"]
    variables:
      DB_HOST: "postgres.default.svc"
      SMTP_SERVER: "smtp.example.com"

schedules:
  hourly:
    schedule: "0 * * * *"
    container_overrides:
      main:
        args: ["generate_report.py", "--type=hourly"]
  daily:
    schedule: "0 8 * * *"
    container_overrides:
      main:
        args: ["generate_report.py", "--type=daily"]
  weekly:
    schedule: "0 8 * * 1"
    container_overrides:
      main:
        args: ["generate_report.py", "--type=weekly"]
```

### Example 3: Job with Files and Volumes

```yaml
metadata:
  name: backup-job

containers:
  main:
    image: backup-tool:latest
    files:
      /config/backup.conf:
        content: |
          [backup]
          destination=/backup
          retention=7
    volumes:
      /backup:
        source: "backup-pvc"
        readOnly: false
    variables:
      AWS_ACCESS_KEY_ID: "..."
      AWS_SECRET_ACCESS_KEY: "..."

schedules:
  nightly:
    schedule: "0 1 * * *"
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cron_job.default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job) | resource |
| [kubernetes_secret.env](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.files](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [random_id.id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_annotations"></a> [additional\_annotations](#input\_additional\_annotations) | Additional annotations to add to all resources. | `map(string)` | `{}` | no |
| <a name="input_containers"></a> [containers](#input\_containers) | The containers section of the Score file. | <pre>map(object({<br/>    image     = string<br/>    command   = optional(list(string))<br/>    args      = optional(list(string))<br/>    variables = optional(map(string))<br/>    files = optional(map(object({<br/>      source        = optional(string)<br/>      content       = optional(string)<br/>      binaryContent = optional(string)<br/>      mode          = optional(string)<br/>      noExpand      = optional(bool)<br/>    })))<br/>    volumes = optional(map(object({<br/>      source   = string<br/>      path     = optional(string)<br/>      readOnly = optional(bool)<br/>    })))<br/>    resources = optional(object({<br/>      limits = optional(object({<br/>        memory = optional(string)<br/>        cpu    = optional(string)<br/>      }))<br/>      requests = optional(object({<br/>        memory = optional(string)<br/>        cpu    = optional(string)<br/>      })))<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_cronjob_spec"></a> [cronjob\_spec](#input\_cronjob\_spec) | CronJob-specific configuration. | <pre>object({<br/>    concurrency_policy            = optional(string)<br/>    failed_jobs_history_limit     = optional(number)<br/>    successful_jobs_history_limit = optional(number)<br/>    starting_deadline_seconds     = optional(number)<br/>    suspend                       = optional(bool)<br/>  })</pre> | `{}` | no |
| <a name="input_job_spec"></a> [job\_spec](#input\_job\_spec) | Job-specific configuration. | <pre>object({<br/>    backoff_limit              = optional(number)<br/>    ttl_seconds_after_finished = optional(number)<br/>    active_deadline_seconds    = optional(number)<br/>    completions                = optional(number)<br/>    parallelism                = optional(number)<br/>  })</pre> | `{}` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | The metadata section of the Score file. | `any` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The Kubernetes namespace to deploy the resources into. | `string` | n/a | yes |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | Map of schedules. Each schedule creates a separate CronJob resource. | <pre>map(object({<br/>    schedule = string<br/>    container_overrides = optional(map(object({<br/>      command = optional(list(string))<br/>      args    = optional(list(string))<br/>    })))<br/>  }))</pre> | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | The name of the service account to use for the pods. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cronjob_names"></a> [cronjob\_names](#output\_cronjob\_names) | Map of schedule keys to CronJob names |
| <a name="output_humanitec_metadata"></a> [humanitec\_metadata](#output\_humanitec\_metadata) | Metadata for Humanitec. |
<!-- END_TF_DOCS -->
