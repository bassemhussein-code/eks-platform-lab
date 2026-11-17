locals {
  account_name = "lab"
  account_id   = "123456789012" # <-- CHANGE: your AWS account id (aws sts get-caller-identity)

  # Multi-account: e.g. "arn:aws:iam::123456789012:role/TerraformDeployer"
  assume_role_arn = ""
}
