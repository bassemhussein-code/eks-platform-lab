# =============================================================================
# Root Terragrunt config. Every unit (vpc, eks, ...) includes this file.
#
# Hierarchy (each level adds/overrides settings -- this is how you scale to
# many accounts / regions / environments without copy-pasting backend config):
#
#   live/
#     root.hcl                  <- remote state + provider (DRY, defined once)
#     <account>/account.hcl     <- account id, (optional) role to assume
#       <region>/region.hcl     <- region
#         <env>/env.hcl         <- cluster name, k8s version, sizes
#           vpc/ eks/ ...       <- units: one state file each
# =============================================================================

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id = local.account_vars.locals.account_id
  region     = local.region_vars.locals.region
  env        = local.env_vars.locals.env

  # Multi-account pattern: Terraform runs with a "deployer" identity and assumes
  # a role in each target account. Leave empty to use your current credentials.
  assume_role_arn = try(local.account_vars.locals.assume_role_arn, "")

  common_tags = {
    Project     = "eks-platform-lab"
    Environment = local.env
    ManagedBy   = "terragrunt"
  }
}

# --- Remote state: one S3 bucket per account+region, one key per unit -------
# Terragrunt creates the bucket on first run. `use_lockfile` = S3-native state
# locking (Terraform >= 1.10). Older setups use a DynamoDB table for locks --
# know both for the interview.
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "tfstate-${local.account_id}-${local.region}-eks-lab"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true
  }
}

# --- AWS provider generated into every unit ----------------------------------
generate "provider_aws" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.region}"
      allowed_account_ids = ["${local.account_id}"]  # guard: never apply to the wrong account
    %{if local.assume_role_arn != ""}
      assume_role {
        role_arn = "${local.assume_role_arn}"
      }
    %{endif}
      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
  EOF
}

# --- Inputs every unit receives (units ignore the ones they don't declare) ---
inputs = merge(
  local.env_vars.locals.inputs,
  {
    region = local.region
    tags   = local.common_tags
  }
)
