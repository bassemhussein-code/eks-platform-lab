include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules//eks"
}

# Terragrunt wires units together through outputs -> inputs and works out
# apply/destroy order from these blocks (vpc -> eks -> demo-irsa / argocd).
dependency "vpc" {
  config_path = "../vpc"

  # Lets `plan`/`validate` run before the VPC exists.
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-aaaa", "subnet-bbbb", "subnet-cccc"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnets
}
