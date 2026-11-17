locals {
  env = "dev"

  inputs = {
    name               = "eks-lab-dev"
    kubernetes_version = "1.36" # lesson 10: upgrade to 1.37 (read the Istio note first!)

    # VPC
    vpc_cidr           = "10.0.0.0/16"
    single_nat_gateway = true

    # EKS
    endpoint_public_access_cidrs = ["0.0.0.0/0"] # <-- CHANGE to ["<your-ip>/32"]
    admin_principal_arns         = []            # e.g. ["arn:aws:iam::123456789012:role/AdminSSO"]
    system_instance_types        = ["t3.large"]

    # GitOps
    gitops_repo_url = "https://github.com/<your-user>/eks-platform-lab.git" # <-- CHANGE
    gitops_revision = "main"
  }
}
