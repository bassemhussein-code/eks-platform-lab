#!/usr/bin/env bash
# Tear the lab down IN THE RIGHT ORDER.
#
# Why order matters (interview-worthy):
#  - Karpenter launches EC2 instances Terraform doesn't know about. Delete the
#    cluster first and those nodes keep running (and billing), and their ENIs
#    block VPC deletion.
#  - The AWS Load Balancer Controller creates ALBs/target groups outside
#    Terraform too. Same problem.
# So: remove what the controllers created, wait, THEN terraform destroy.
set -euo pipefail

ENV_DIR="$(cd "$(dirname "$0")/../live/lab-account/eu-central-1/dev" && pwd)"
CLUSTER="eks-lab-dev"
REGION="eu-central-1"

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null

echo ">> 1. Stop GitOps from re-creating things (root app has no finalizer -> children stay)"
kubectl -n argocd delete application platform-root --ignore-not-found

echo ">> 2. Delete demo workloads (removes the ALB Ingress if exposed)"
kubectl -n argocd delete application demo-workloads --ignore-not-found --wait=true
echo "   waiting 60s for the ALB to be deleted by the controller..."
sleep 60

echo ">> 3. Delete Karpenter NodePool/EC2NodeClass -> Karpenter drains and terminates its nodes"
kubectl -n argocd delete application karpenter-config --ignore-not-found --wait=true
echo "   waiting for all NodeClaims to disappear..."
for i in $(seq 1 60); do
  n=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = "0" ] && break
  echo "   $n nodeclaim(s) left"; sleep 10
done

echo ">> 4. Terraform destroy (reverse dependency order)"
cd "$ENV_DIR"
terragrunt run --all destroy

echo ">> Done. Double-check: EC2 > Instances and EC2 > Load Balancers should be empty for this lab."
