# Learning path

Each lesson has the same shape: **Read** the files → **Do** the commands → **Break it** (the debugging is where the learning happens) → **Interview questions** to answer out loud. We go through them together, one at a time.

| # | Lesson | JD line it covers |
|---|---|---|
| 0 | Terraform + Terragrunt structure, remote state | Terraform & Terragrunt modules, multi-account |
| 1 | VPC design for EKS | VPC, subnets, NAT |
| 2 | EKS cluster: control plane, access entries, add-ons | EKS cluster lifecycle |
| 3 | Networking: VPC CNI + AWS Load Balancer Controller | ALB/NLB |
| 4 | IAM for pods: IRSA vs Pod Identity | IAM, Wiz findings |
| 5 | Karpenter | Karpenter autoscaling, cost |
| 6 | Argo CD app-of-apps | GitOps with Argo CD |
| 7 | Kyverno | Policy & governance |
| 8 | Falco | Runtime security |
| 9 | Istio ambient vs sidecar | Service mesh, mTLS, retries, circuit breaking |
| 10 | Observability & SLOs | Prometheus, SLOs/SLIs/error budgets |
| 11 | Zero-downtime EKS upgrade 1.36 → 1.37 | Upgrades, add-on lifecycle |
| 12 | Incident drills + teardown | Incident response, RCA |

---

## Lesson 0: Terraform + Terragrunt

**Read:** `live/root.hcl`, `live/lab-account/**/{account,region,env}.hcl`, one unit `terragrunt.hcl`

**Do**
```bash
cd live/lab-account/eu-central-1/dev
terragrunt run --all plan       # mocks let eks/argocd plan before vpc exists
terragrunt dag graph            # dependency graph (older: terragrunt graph-dependencies)
```
**Break it:** set `account_id` to a wrong number → the `allowed_account_ids` guard stops you.

**Interview:** Why Terragrunt on top of Terraform? How is state split, and why one state per unit? S3 native locking vs DynamoDB? How would you add a `prod` account in another region?

## Lesson 1: VPC

**Read:** `modules/vpc/main.tf`

**Interview:** Why /20 private subnets? What do the `kubernetes.io/role/elb` and `karpenter.sh/discovery` tags do? Single NAT vs. one per AZ: cost vs. availability.

## Lesson 2: EKS cluster

**Read:** `modules/eks/main.tf` (top half)

**Do**
```bash
aws eks describe-cluster --name eks-lab-dev --query 'cluster.{v:version,ep:endpoint,access:accessConfig}'
aws eks list-access-entries --cluster-name eks-lab-dev
aws eks list-addons --cluster-name eks-lab-dev
kubectl get nodes -o wide
```
**Break it:** add a teammate's role ARN to `admin_principal_arns`, apply, and have them log in. Then remove it.

**Interview:** What does AWS manage vs. you? Access entries vs. `aws-auth`? Why `before_compute` on vpc-cni? Managed add-ons vs. Helm?

## Lesson 3: VPC CNI + Load Balancer Controller

**Do**
```bash
kubectl -n kube-system get ds aws-node -o yaml | grep -A1 PREFIX
kubectl get pods -A -o wide | head          # pod IPs are real VPC IPs
# expose httpbin: set addons.demoWorkloads.exposeDemo=true (+ your IP) in gitops/bootstrap/values.yaml, push
kubectl -n demo-sidecar get ingress httpbin  # ALB DNS name after ~2 min
```
**Break it:** remove the `PeerAuthentication` port exception → the ALB gets 502s. Explain why.

**Interview:** `target-type: ip` vs `instance`? How do you debug ALB 502/503? What causes pod IP exhaustion, and what are 3 fixes?

## Lesson 4: IRSA vs Pod Identity

**Read:** `modules/demo-irsa/main.tf`, `gitops/charts/demo-workloads/templates/s3-reader-irsa.yaml`, Pod Identity modules in `modules/eks/main.tf`

**Do**
```bash
kubectl -n demo-ambient logs deploy/s3-reader
kubectl -n demo-ambient get pod -l app=s3-reader -o yaml | grep -E 'AWS_ROLE_ARN|AWS_WEB_IDENTITY'
aws eks list-pod-identity-associations --cluster-name eks-lab-dev
```
**Break it** (this is the drill from our session):
1. Change the trust policy `sub` to `...:s3-readerX` → AccessDenied. Find it from the pod outward.
2. Remove the SA annotation → the pod uses the node role → blocked by IMDS hop limit 1.

**Interview:** Walk through the IRSA token flow end to end. When do you choose Pod Identity over IRSA? Why must app permissions never go on the node role?

## Lesson 5: Karpenter

**Read:** `gitops/charts/karpenter-config/templates/*`, Karpenter module in `modules/eks/main.tf`

**Do**
```bash
kubectl -n demo-ambient scale deploy httpbin --replicas=30
kubectl get nodeclaims -w
kubectl -n kube-system logs deploy/karpenter -f | grep -i -E 'launched|disrupt'
kubectl -n demo-ambient scale deploy httpbin --replicas=2   # watch consolidation
```
**Break it:** set `cpuLimit: "2"` → pods stay Pending. Read the Karpenter logs to see why.

**Interview:** Karpenter vs. Cluster Autoscaler? How do you handle Spot interruption? What are disruption budgets for? What is drift, and how do you roll out a new AMI safely?

## Lesson 6: Argo CD

**Read:** `modules/argocd/main.tf`, `gitops/bootstrap/**`

**Do:** open the UI (`./scripts/access.sh`) and follow the sync waves. Change a value in Git, push, watch it sync. Then `kubectl edit` a managed resource and watch self-heal revert it.

**Break it:** delete the Application health Lua from `argocd-cm` → waves stop waiting for each other. What breaks?

**Interview:** App-of-apps vs. ApplicationSet? How do you promote add-on versions dev → prod? How does Terraform hand values to Argo (the GitOps bridge)? Exercise: convert `demo-workloads` to an ApplicationSet.

## Lesson 7: Kyverno

**Do**
```bash
kubectl get clusterpolicy
kubectl get policyreport -A
kubectl run bad --image=nginx:latest -n demo-sidecar
```
Then fix the violations and flip `failureAction: Enforce` on `disallow-latest-tag`. Try the bad pod again.

**Interview:** Kyverno vs. OPA Gatekeeper? Audit → Enforce rollout strategy? What happens to the cluster if the Kyverno webhook is down (`failurePolicy`)?

## Lesson 8: Falco

**Do**
```bash
kubectl -n demo-sidecar exec -it deploy/traffic-client -c curl -- sh   # "Terminal shell in container"
kubectl -n falco logs ds/falco -c falco | grep -i -E 'shell|package'
```
**Interview:** Admission-time vs. runtime security: why do you need both? How would you route Falco alerts (Falcosidekick → Slack/SIEM)?

## Lesson 9: Istio ambient vs sidecar

**Read:** `gitops/charts/demo-workloads/templates/mesh-*.yaml`

**Do**
```bash
kubectl get pods -n demo-sidecar   # 2/2 containers (sidecar)
kubectl get pods -n demo-ambient   # 1/1 + a waypoint pod
istioctl ztunnel-config workloads
# authz: call ambient httpbin from the SIDECAR namespace client (wrong identity) -> 403
kubectl -n demo-sidecar exec deploy/traffic-client -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://httpbin.demo-ambient:8000/get
# timeout: /delay/5 vs 3s HTTPRoute timeout -> 504
kubectl -n demo-ambient exec deploy/traffic-client -- curl -s -o /dev/null -w '%{http_code}\n' http://httpbin:8000/delay/5
```
**Version pinning task:** replace every `*` chart version in `gitops/bootstrap/values.yaml` with the exact version Argo installed.

**Interview:** ztunnel vs. waypoint (what is L4 vs. L7)? When do you still pick sidecars? How do mTLS identities work (SPIFFE)? Retries + timeouts + outlier detection: how do they interact?

## Lesson 10: Observability & SLOs

**Read:** `gitops/charts/demo-workloads/templates/slo-rules.yaml`

**Do:** in Prometheus, query `slo:httpbin_error_ratio:rate5m`. Then make the client send 30% 500s and watch `HttpbinErrorBudgetFastBurn` fire.

**Interview:** SLI vs. SLO vs. SLA? What is an error budget, and what happens when it runs out? Why use multi-window burn-rate alerts instead of "error rate > 1%"?

## Lesson 11: Zero-downtime upgrade 1.36 → 1.37

1. **Pre-flight:** EKS Cluster Insights, deprecated APIs (`kubent`/`pluto`), add-on compatibility.
   **The trap:** Istio 1.30 supports Kubernetes up to 1.36. Upgrade Istio to 1.31 first. From 1.31 the charts are published at a new location, so `addons.istio.repoURL` must change too.
2. Check PDBs, replicas and topology spread (already in place for httpbin).
3. `kubernetes_version = "1.37"` → apply the `eks` unit (control plane, then add-ons with `most_recent`).
4. Nodes: the managed node group rolls; Karpenter nodes **drift** and get replaced within budgets.
5. Validate: SLO dashboard, `kubectl get nodes`, Argo apps all Healthy.

**Interview:** Why can't you skip versions or roll back the control plane? Blue/green cluster vs. in-place?

## Lesson 12: Incident drills

I'll break something without telling you. You get only the symptoms and work to a root cause and an RCA write-up. Then `./scripts/down.sh`.
