data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# 3 AZs. Private subnets are /20 (4,096 IPs each) because the VPC CNI gives
# every pod a real VPC IP -- small subnets are the #1 cause of IP exhaustion.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]      # 10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)] # 10.0.48.0/24 ...

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway # true = cheap lab, false = one NAT per AZ (prod)
  enable_dns_hostnames = true

  # The AWS Load Balancer Controller uses these tags to discover subnets.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  # Karpenter discovers the subnets to launch nodes into with this tag.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.name
  }

  tags = var.tags
}
