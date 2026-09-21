# Runbook: PodCrashLoopBackOff

**Fires when:** a pod in `app` namespace restarts more than 3 times in 15 minutes.

## Triage
1. `kubectl describe pod -n app <pod>` - check `Last State: Terminated` reason (OOMKilled vs Error vs
   failed liveness probe).
2. `kubectl logs -n app <pod> --previous` - logs from the crashed instance, not the current restart.

## Common causes
- **OOMKilled**: container hit its memory `limit`. Check Grafana memory panel over the last hour; if this is
  a genuine load increase, raise `resources.limits.memory` in the overlay via PR. If it's a leak, roll back.
- **Failed liveness probe**: `/healthz` timing out - check CPU throttling (`container_cpu_cfs_throttled_seconds_total`)
  before assuming app-level failure; a starved container can fail liveness checks it would otherwise pass.
- **ImagePullBackOff masquerading as crash loop**: check `kubectl describe pod` events for `ErrImagePull` -
  usually a bad tag from a failed promotion; verify `kustomization.yaml` in the overlay has the right tag.

## Escalation
If the rollback doesn't stabilize the pod within 10 minutes, treat as a P1 and page the service owner.
