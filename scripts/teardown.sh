#!/usr/bin/env bash
# Reverse of bootstrap.sh: removes platform tooling, then destroys infra.
# Run in this order to avoid orphaned ELBs/PVs blocking `terraform destroy`.
set -euo pipefail

ENV="${1:?Usage: teardown.sh <dev|staging|prod>}"

echo "==> Deleting Argo CD Applications (prevents recreation during teardown)"
kubectl delete -f ../gitops/argocd/applications/app-of-apps.yaml --ignore-not-found

echo "==> Uninstalling Helm releases"
for release in loki kps external-secrets kyverno argocd ingress-nginx; do
  ns=$(helm list -A -o json | python3 -c "import sys,json;d=json.load(sys.stdin);print(next((r['namespace'] for r in d if r['name']=='$release'),''))")
  [ -n "$ns" ] && helm uninstall "$release" -n "$ns" || true
done

echo "==> Destroying Terraform-managed AWS infra for ${ENV}"
(cd "../terraform/environments/${ENV}" && terraform destroy)

echo "==> Teardown complete."
