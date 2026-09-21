# Disaster Recovery

## RPO / RTO targets
| Component | RPO | RTO |
|---|---|---|
| Application (stateless) | N/A (rebuilt from git) | < 10 min (Argo CD re-sync + HPA warmup) |
| RDS (PostgreSQL) | 5 min (automated snapshots + PITR) | < 1 hour |
| Cluster config (manifests) | 0 (git is the source of truth) | Minutes (re-apply app-of-apps to a new cluster) |
| Secrets | 0 (source is AWS Secrets Manager, replicated per region on request) | Minutes |

## Scenario: entire EKS cluster is lost (region-level AZ failure, accidental `terraform destroy`, etc.)

1. **Infra**: `cd terraform/environments/prod && terraform apply` recreates VPC, EKS, IAM/IRSA, and
   re-points at the *existing* RDS instance (state for RDS should live in a separate Terraform state/workspace
   from the cluster itself in a real prod setup, so a cluster rebuild never risks the database).
2. **Bootstrap tooling**: `./scripts/bootstrap.sh prod` reinstalls Argo CD, Kyverno, External Secrets,
   Prometheus stack, Loki — all from the same Helm values checked into this repo.
3. **Reconcile applications**: `kubectl apply -f gitops/argocd/applications/app-of-apps.yaml`. Argo CD
   reads `kubernetes/overlays/prod` from git and deploys the exact last-known-good image tag. No manual
   `kubectl apply` of application manifests is ever needed — that's the point of GitOps.
4. **Verify**: check the `HighErrorRateFastBurn` and readiness of all pods in Grafana before flipping DNS/ALB
   back if a blue/green DR pattern was used.

## Scenario: RDS instance corrupted / bad migration
1. Restore from the latest automated snapshot or a point-in-time restore into a new instance.
2. Update the `platform-prod/app/db-credentials` secret in Secrets Manager with the new endpoint.
3. External Secrets Operator's `refreshInterval: 1h` will pick it up automatically, or force it immediately:
   `kubectl annotate externalsecret app-db-credentials -n app force-sync=$(date +%s) --overwrite`.

## Scenario: bad deploy reaches prod
1. In Argo CD: `argocd app rollback platform-app-prod <previous-revision>` — instant, since Argo CD keeps
   revision history of every synced git commit.
2. Alternatively, revert the image-tag commit in `kubernetes/overlays/prod/kustomization.yaml` via git revert
   and let Argo CD auto-heal back to the reverted state.
3. The `HighErrorRateFastBurn` alert (5% error rate over 5 min) is tuned to catch this class of incident
   before most users notice.

## Backup verification
Snapshot restores should be **tested quarterly** into the staging environment, not just taken on faith —
an untested backup is not a backup.
