# EKS Platform Lab

A production-style Kubernetes platform on **AWS EKS**, built with **Terraform + Terragrunt** and run with **Argo CD GitOps**. It covers:

| Area | What's in the lab |
|---|---|
| EKS | EKS 1.36, access entries (no `aws-auth`), managed add-ons, VPC CNI prefix delegation, control-plane audit logs |
| Compute | **Karpenter** (NodePool + EC2NodeClass, spot + on-demand, consolidation, disruption budgets, drift) |
| IAM | **EKS Pod Identity** for add-ons, hand-written **IRSA** for an app, IMDSv2 hop-limit 1 |
| Networking | AWS Load Balancer Controller (ALB, `target-type: ip`) |
| Service mesh | **Istio ambient** (ztunnel + waypoint) **and** sidecar mode side by side: mTLS STRICT, L7 authz, retries, timeouts, circuit breaking |
| Policy | **Kyverno**: 4 validating policies (Audit → Enforce) + 1 mutating policy |
| Runtime security | **Falco** (modern eBPF) with a custom rule |
| Observability | kube-prometheus-stack, Istio metrics, **SLO with multi-window burn-rate alerts** |
| GitOps | Argo CD **app-of-apps**, sync waves, health checks, Terraform → Argo "GitOps bridge" |
| IaC | Terraform modules + **Terragrunt** (DRY remote state, account/region/env hierarchy, dependencies) |

## Architecture

```
                      ┌───────────── Terraform / Terragrunt ─────────────┐
                      │  vpc  ──►  eks  ──►  demo-irsa  ──►  argocd       │
                      └────────────────────────────────────────┬─────────┘
                                                               │ installs Argo CD + 1 root app
                                                               ▼
   Git repo (gitops/) ───────────────────────────────►  Argo CD (app-of-apps)
                                                               │
   wave 0  gateway-api CRDs · aws-load-balancer-controller · karpenter
   wave 1  karpenter-config (NodePool/EC2NodeClass) · istio-base · kube-prometheus-stack
   wave 2  istiod (ambient profile) · kyverno
   wave 3  istio-cni · ztunnel · istio-monitoring · kyverno-policies · falco
   wave 5  demo-workloads (httpbin ambient + sidecar, IRSA S3 reader, SLO rules)

  VPC 10.0.0.0/16, 3 AZs
  ├─ public  /24 x3  → NAT GW, ALBs
  └─ private /20 x3  → system node group (2x t3.large) + Karpenter nodes (spot/on-demand)
```

## Repo layout

```
modules/            Terraform modules (reusable, no env-specific values)
  vpc/              terraform-aws-modules/vpc + EKS/Karpenter subnet tags
  eks/              cluster, add-ons, access entries, system node group,
                    Karpenter IAM/SQS, Pod Identity for LBC + EBS CSI
  demo-irsa/        S3 bucket + IRSA role written by hand (learn every piece)
  argocd/           Helm-installs Argo CD + the root Application
live/               Terragrunt: where modules get real values
  root.hcl          remote state (S3 + native lock), provider generation
  lab-account/account.hcl → eu-central-1/region.hcl → dev/env.hcl → units
gitops/
  bootstrap/        app-of-apps chart (one Application per add-on, sync waves)
  charts/           karpenter-config, demo-workloads
  platform/         kyverno-policies, istio-monitoring
scripts/            up.sh, down.sh (ordered teardown), access.sh
LESSONS.md          the step-by-step learning path
```

## Prerequisites

- AWS account with admin access; `aws` CLI v2 configured
- `terraform` >= 1.10, `terragrunt` (recent), `kubectl`, `helm`
- Optional: `istioctl`, `k9s`, `eks-node-viewer`
- One-time, if your account never used Spot:
  `aws iam create-service-linked-role --aws-service-name spot.amazonaws.com`

## 💰 Cost: destroy it when you stop

Running costs: the EKS control plane, 2× t3.large, a NAT gateway, CloudWatch logs and any Karpenter nodes. Run the lab in sessions and **`./scripts/down.sh` every time**. Set an AWS Budget alert before you start.

## Quick start

1. **Push this repo to your GitHub** (public is simplest; Argo CD reads `gitops/` from it).
2. Edit the 3 `CHANGE` markers:
   - `live/lab-account/account.hcl` → `account_id`
   - `live/lab-account/eu-central-1/dev/env.hcl` → `gitops_repo_url`, `endpoint_public_access_cidrs` (your IP/32)
3. Bring it up:
   ```bash
   ./scripts/up.sh          # ~25 min
   ./scripts/access.sh      # Argo CD :8080, Grafana :3000, Prometheus :9090
   ```
4. Tear it down:
   ```bash
   ./scripts/down.sh
   ```

> Older Terragrunt versions use `terragrunt run-all apply` instead of `terragrunt run --all apply`.

Then follow **[LESSONS.md](LESSONS.md)**.
