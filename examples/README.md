# v1 to v2 CronJob Migration Example

This example shows how to use the score-cronjob-kubernetes module with v2-style Score files.

## Quick Start

### Score File Structure

In v2, all v1 `humanitec.score.yaml` extensions are embedded directly in the metadata section of the Score file:

```yaml
apiVersion: score.dev/v1b1

metadata:
  name: my-cronjob
  annotations:
    humanitec.dev/resType: "score-cronjob"  # Switch to score-cronjob resource type

  # Copy all v1 humanitec.score.yaml content here:
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

## Migration from v1

### v1 Structure (Two Files)

**score.yaml:**
```yaml
apiVersion: score.dev/v1b1
metadata:
  name: my-cronjob
containers:
  main-container:
    image: .
```

**humanitec.score.yaml:**
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

### v2 Structure (Single File)

Simply copy the `spec` content from `humanitec.score.yaml` into the `metadata` section:

```yaml
apiVersion: score.dev/v1b1

metadata:
  name: my-cronjob
  annotations:
    humanitec.dev/resType: "score-cronjob"

  # Paste v1 spec content here (without the "spec:" key):
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

## Supported Fields

All v1 `humanitec.score.yaml` fields are supported when placed in metadata:

- `schedules` - Multiple schedules with container overrides
- `cronjob` - CronJob spec (concurrencyPolicy, timeZone, annotations, labels)
- `job` - Job spec (activeDeadlineSeconds, ttlSecondsAfterFinished, annotations, labels)
- `pod` - Pod spec (nodeSelector, os, annotations, labels)

## Deployment

Deploy with `hctl score deploy`:

```bash
hctl score deploy my-project my-env score.yaml --default-image my-image:latest
```

The CLI will:
1. Read the `humanitec.dev/resType` annotation to determine this is a `score-cronjob` workload
2. Pass the entire metadata section to the module
3. The module extracts schedules and other extensions from metadata
