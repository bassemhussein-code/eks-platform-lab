################################################################################
# Terraform's LAST job: install Argo CD and hand it one "root" Application.
# From here on, every add-on is managed by Git (app-of-apps), not Terraform.
#
# Terraform -> Argo CD is the "GitOps bridge": Terraform knows AWS facts
# (VPC id, Karpenter queue, account id) and passes them to Argo as Helm values.
################################################################################

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version # null = latest; pin it after first install (lesson 9)
  wait             = true
  timeout          = 900

  values = [yamlencode({
    global = {
      nodeSelector = { "workload-type" = "system" }
    }
    dex = { enabled = false }
    configs = {
      params = {
        "server.insecure" = true # lab: we reach the UI with kubectl port-forward
      }
      cm = {
        "timeout.reconciliation" = "60s"
        # Argo CD does not compute health for Application objects by default.
        # Without this, sync waves in app-of-apps do NOT wait for child apps
        # to become Healthy -- everything syncs at once and CRD-ordering breaks.
        "resource.customizations.health.argoproj.io_Application" = <<-LUA
          hs = {}
          hs.status = "Progressing"
          hs.message = ""
          if obj.status ~= nil then
            if obj.status.health ~= nil then
              hs.status = obj.status.health.status
              if obj.status.health.message ~= nil then
                hs.message = obj.status.health.message
              end
            end
          end
          return hs
        LUA
      }
    }
  })]
}

# Karpenter's chart lives in an OCI registry; Argo needs a repo entry for it.
resource "kubernetes_secret_v1" "karpenter_oci_repo" {
  metadata {
    name      = "repo-karpenter-oci"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    name      = "karpenter"
    url       = "public.ecr.aws/karpenter"
    type      = "helm"
    enableOCI = "true"
  }

  depends_on = [helm_release.argocd]
}

# The root Application (rendered from a tiny local chart so Terraform doesn't
# need the Application CRD to exist at plan time).
resource "helm_release" "root_app" {
  name      = "platform-root"
  namespace = "argocd"
  chart     = "${path.module}/charts/root-app"

  values = [yamlencode({
    repoURL        = var.gitops_repo_url
    targetRevision = var.gitops_revision
    cluster = {
      name      = var.name
      region    = var.region
      accountId = data.aws_caller_identity.current.account_id
      vpcId     = var.vpc_id
      karpenter = {
        queueName    = var.karpenter_queue_name
        nodeRoleName = var.karpenter_node_role_name
      }
    }
  })]

  depends_on = [helm_release.argocd, kubernetes_secret_v1.karpenter_oci_repo]
}
