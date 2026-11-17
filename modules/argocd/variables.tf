variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "karpenter_queue_name" {
  type = string
}

variable "karpenter_node_role_name" {
  type = string
}

variable "gitops_repo_url" {
  description = "HTTPS URL of YOUR copy of this repo (Argo CD reads gitops/ from it)."
  type        = string
}

variable "gitops_revision" {
  type    = string
  default = "main"
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version. null = latest."
  type        = string
  default     = null
}
