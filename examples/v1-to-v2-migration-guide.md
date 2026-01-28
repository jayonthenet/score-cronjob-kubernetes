# v1 to v2 CronJob Migration Guide

## Overview

In v1, CronJob workloads required two files:
- `score.yaml` - Standard Score specification
- `humanitec.score.yaml` - Humanitec extensions (profile, schedules, specs)

In v2, everything goes into a **single Score file** with extensions embedded in the `metadata` section.

## Migration Steps

### Step 1: Copy Your v1 Files

**v1 score.yaml:**
```yaml
apiVersion: score.dev/v1b1

metadata:
  name: my-cronjob

containers:
  main-container:
    image: .
```

**v1 humanitec.score.yaml:**
```yaml
apiVersion: humanitec.org/v1b1
profile: humanitec/default-cronjob

spec:
  schedules:
    6-hour-run:
      schedule: "0-59 * * * *"
      containers:
        main-container:
          args: ["-c", "echo 'Running 6-hour scheduled task'; sleep 10"]
  cronjob:
    annotations:
      cronjobannotationkey: cronjobannotationvalue
    labels:
      cronjoblabelkey: cronjoblabelvalue
    concurrencyPolicy: Forbid
    timeZone: Africa/Lagos
  job:
    annotations:
      jobannotationkey: jobannotationvalue
    labels:
      joblabelkey: joblabelvalue
    activeDeadlineSeconds: 30
    ttlSecondsAfterFinished: 3600
  pod:
    annotations:
      podannotationkey: podannotationvalue
    labels:
      podlabelkey: podlabelvalue
    nodeSelector:
      topology.kubernetes.io/region: northeurope
    os:
      name: linux
```

### Step 2: Merge into Single v2 Score File

1. Start with your v1 `score.yaml`
2. Add the resource type annotation
3. Copy the **content** of `spec:` from `humanitec.score.yaml` into `metadata:`

**v2 score.yaml:**
```yaml
apiVersion: score.dev/v1b1

metadata:
  name: my-cronjob
  annotations:
    humanitec.dev/resType: "score-cronjob"  # NEW: Tell hctl to use score-cronjob

  # PASTE the v1 spec content here (everything under "spec:" in humanitec.score.yaml):
  schedules:
    6-hour-run:
      schedule: "0-59 * * * *"
      containers:
        main-container:
          args: ["-c", "echo 'Running 6-hour scheduled task'; sleep 10"]

  cronjob:
    annotations:
      cronjobannotationkey: cronjobannotationvalue
    labels:
      cronjoblabelkey: cronjoblabelvalue
    concurrencyPolicy: Forbid
    timeZone: Africa/Lagos

  job:
    annotations:
      jobannotationkey: jobannotationvalue
    labels:
      joblabelkey: joblabelvalue
    activeDeadlineSeconds: 30
    ttlSecondsAfterFinished: 3600

  pod:
    annotations:
      podannotationkey: podannotationvalue
    labels:
      podlabelkey: podlabelvalue
    nodeSelector:
      topology.kubernetes.io/region: northeurope
    os:
      name: linux

containers:
  main-container:
    image: busybox:latest
    command: ["/bin/sh"]
    args: ["-c", "echo 'Running scheduled task'; sleep 10"]
```

### Step 3: Deploy

```bash
hctl score deploy my-project my-env score.yaml --default-image my-image:latest
```

## Field Mapping Reference

| v1 Location | v2 Location | Notes |
|-------------|-------------|-------|
| `humanitec.score.yaml` → `spec.schedules` | `score.yaml` → `metadata.schedules` | Same structure |
| `humanitec.score.yaml` → `spec.cronjob` | `score.yaml` → `metadata.cronjob` | Same structure |
| `humanitec.score.yaml` → `spec.job` | `score.yaml` → `metadata.job` | Same structure |
| `humanitec.score.yaml` → `spec.pod` | `score.yaml` → `metadata.pod` | Same structure |
| `humanitec.score.yaml` → `profile: humanitec/default-cronjob` | `score.yaml` → `metadata.annotations.humanitec.dev/resType: "score-cronjob"` | Controls resource type |

## Complete Field Support

All v1 fields are fully supported in v2 when placed in metadata:

### Schedules
```yaml
metadata:
  schedules:
    schedule-name:
      schedule: "cron expression"
      containers:  # v1 style
        container-name:
          args: [...]
          command: [...]
      # OR
      container_overrides:  # v2 style (both work!)
        container-name:
          args: [...]
          command: [...]
```

### CronJob Spec
```yaml
metadata:
  cronjob:
    concurrencyPolicy: "Allow|Forbid|Replace"
    timeZone: "Africa/Lagos"
    failedJobsHistoryLimit: 3
    successfulJobsHistoryLimit: 5
    startingDeadlineSeconds: 60
    suspend: false
    annotations:
      key: value
    labels:
      key: value
```

### Job Spec
```yaml
metadata:
  job:
    activeDeadlineSeconds: 30
    ttlSecondsAfterFinished: 3600
    backoffLimit: 3
    completions: 1
    parallelism: 1
    annotations:
      key: value
    labels:
      key: value
```

### Pod Spec
```yaml
metadata:
  pod:
    nodeSelector:
      topology.kubernetes.io/region: northeurope
    os:
      name: linux
    annotations:
      key: value
    labels:
      key: value
```

## How It Works

1. **hctl score deploy** reads your Score file
2. Sees `annotations.humanitec.dev/resType: "score-cronjob"`
3. Passes the entire `metadata` object to the module
4. The module extracts:
   - `metadata.schedules` → creates CronJob resources
   - `metadata.cronjob` → applies CronJob spec
   - `metadata.job` → applies Job spec
   - `metadata.pod` → applies Pod spec
   - `metadata.*.annotations` → applies annotations
   - `metadata.*.labels` → applies labels

## Validation

The module validates that:
- At least one schedule is defined in `metadata.schedules`
- Schedule cron expressions are valid (Kubernetes will validate)
- All referenced containers exist

## Troubleshooting

### Error: "At least one schedule must be defined"
Add `schedules` to your metadata:
```yaml
metadata:
  schedules:
    daily:
      schedule: "0 0 * * *"
```

### CronJob not using correct timezone
Ensure:
1. Your cluster is Kubernetes 1.25+
2. Uncomment the `time_zone` line in the module's main.tf (line ~153)
3. Add timezone to metadata:
```yaml
metadata:
  cronjob:
    timeZone: "Africa/Lagos"
```

### Labels not appearing
Check that labels are in the correct section:
```yaml
metadata:
  cronjob:
    labels:
      cronjob-label: value
  job:
    labels:
      job-label: value
  pod:
    labels:
      pod-label: value
```

## See Also

- [score.yaml](score.yaml) - Complete v2 example
- [README.md](README.md) - Quick start guide
