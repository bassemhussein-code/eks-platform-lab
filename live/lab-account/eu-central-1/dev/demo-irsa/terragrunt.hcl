include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules//demo-irsa"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/MOCK"
    oidc_provider     = "oidc.eks.eu-central-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_provider     = dependency.eks.outputs.oidc_provider
  namespace         = "demo-ambient"
  service_account   = "s3-reader"
}
