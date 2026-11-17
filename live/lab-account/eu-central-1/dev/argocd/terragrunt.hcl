include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules//argocd"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name             = "eks-lab-dev"
    karpenter_queue_name     = "mock-queue"
    karpenter_node_role_name = "mock-role"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# The demo app's S3 role must exist before Argo deploys the pod that uses it.
dependencies {
  paths = ["../demo-irsa"]
}

inputs = {
  name                     = dependency.eks.outputs.cluster_name
  vpc_id                   = dependency.vpc.outputs.vpc_id
  karpenter_queue_name     = dependency.eks.outputs.karpenter_queue_name
  karpenter_node_role_name = dependency.eks.outputs.karpenter_node_role_name
}
