# Runbook: HighErrorRateFastBurn / HighErrorRateSlowBurn

**Fires when:** 5xx rate exceeds 2% over 5 min (fast burn) or 1% over 1h (slow burn).

## Triage (first 5 minutes)
1. Open the `platform-app-overview` Grafana dashboard - check if the error spike correlates with a recent
   deploy (Argo CD app history timestamp) or a dependency (RDS `readyz` failures in Loki).
2. `kubectl get pods -n app` - look for `CrashLoopBackOff` or high restart counts.
3. `kubectl logs -n app -l app=platform-app --since=10m | grep -i error` (or query the same in Loki via Grafana Explore).

## Likely causes and actions
- **Recent deploy**: `argocd app rollback platform-app-<env> <previous-rev>` to revert immediately, then
  investigate the bad commit offline.
- **Database unreachable** (`/readyz` returning 503): check RDS status in the AWS console; check the
  `app-db-credentials` ExternalSecret synced successfully (`kubectl describe externalsecret -n app`).
- **Downstream dependency timeout**: check `HighP99Latency` alert state; consider temporarily lowering HPA
  `averageUtilization` target to add headroom while the dependency recovers.
- **Traffic spike beyond HPA `maxReplicas`**: check `HPAAtMaxReplicas`; bump `maxReplicas` in the overlay as a
  stopgap, file a follow-up to right-size capacity planning.

## Escalation
If unresolved in 15 minutes or error rate exceeds 10%, page the secondary on-call and open an incident channel.
