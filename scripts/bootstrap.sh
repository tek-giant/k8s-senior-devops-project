#!/usr/bin/env bash
# Bootstraps the platform tooling onto an already-provisioned EKS cluster
# (run `terraform apply` in terraform/environments/<env> first).
#
# Usage: ./bootstrap.sh <dev|staging|prod>
set -euo pipefail

ENV="${1:?Usage: bootstrap.sh <dev|staging|prod>}"
CLUSTER_NAME="platform-${ENV}"
REGION="eu-west-2"

echo "==> Configuring kubectl for ${CLUSTER_NAME}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo "==> Adding Helm repos"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add kyverno https://kyverno.github.io/kyverno
helm repo add external-secrets https://charts.external-secrets.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

echo "==> Ingress controller"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace

echo "==> Argo CD"
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f ../gitops/argocd/install/values-argocd.yaml

echo "==> Kyverno (admission policies)"
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl apply -f ../security/policies/

echo "==> External Secrets Operator"
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
kubectl apply -f ../security/external-secrets/secretstore.yaml

echo "==> kube-prometheus-stack (Prometheus + Grafana + Alertmanager)"
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n observability --create-namespace \
  -f ../observability/prometheus/values-kube-prometheus-stack.yaml
kubectl apply -f ../observability/alerts/

echo "==> Loki (log aggregation)"
helm upgrade --install loki grafana/loki-stack \
  -n observability -f ../observability/loki/values-loki-stack.yaml

echo "==> Done. Next: kubectl apply -f ../gitops/argocd/applications/app-of-apps.yaml"
