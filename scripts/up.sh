#!/usr/bin/env bash
# Bring the whole lab up: VPC -> EKS -> demo IRSA role -> Argo CD (+ everything via GitOps)
set -euo pipefail

ENV_DIR="$(cd "$(dirname "$0")/../live/lab-account/eu-central-1/dev" && pwd)"
CLUSTER="eks-lab-dev"
REGION="eu-central-1"

echo ">> Checking AWS identity"
aws sts get-caller-identity

echo ">> Applying all units (Terragrunt resolves the dependency order)"
cd "$ENV_DIR"
terragrunt run --all apply

echo ">> Configuring kubectl"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

echo ">> Argo CD applications (they need a few minutes to become Healthy)"
kubectl get applications -n argocd

cat <<EOF

Next:
  ./scripts/access.sh         # Argo CD + Grafana UIs and passwords
  kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type,topology.kubernetes.io/zone
EOF
