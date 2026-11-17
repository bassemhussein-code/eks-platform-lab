################################################################################
# EKS cluster
#  - Control plane: managed by AWS (you only pick version, endpoint access, logs)
#  - Data plane:    a small managed node group for "system" pods (Karpenter itself,
#                   Argo CD, CoreDNS). Everything else is provisioned by Karpenter.
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  # Lab: public endpoint so you can run kubectl from your laptop. Lock it to your IP.
  # Prod: private endpoint + VPN/bastion, or public restricted to CI/VPN CIDRs.
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Control-plane logs to CloudWatch ("audit" is what security teams ask for).
  enabled_log_types = ["api", "audit", "authenticator"]

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  ##############################################################################
  # Access entries (the replacement for the aws-auth ConfigMap)
  ##############################################################################
  # Whoever runs terraform becomes cluster admin.
  enable_cluster_creator_admin_permissions = true

  # Extra admins (e.g. an SSO role, a CI role) -- managed by the EKS API, not a ConfigMap.
  access_entries = {
    for idx, arn in var.admin_principal_arns : "admin-${idx}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  ##############################################################################
  # EKS managed add-ons (versioned against the cluster version)
  ##############################################################################
  addons = {
    # before_compute = installed before node groups, so nodes join with the right CNI config
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          # Prefix delegation: each ENI slot gets a /28 (16 IPs) -> many more pods per node
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  ##############################################################################
  # System node group (static, small). Workloads go to Karpenter nodes.
  ##############################################################################
  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.system_instance_types

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        "workload-type" = "system"
        # Karpenter's controller must NOT run on nodes it manages itself
        "karpenter.sh/controller" = "true"
      }
    }
  }

  # Karpenter discovers the node security group with this tag.
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.name
  }

  tags = var.tags
}

################################################################################
# Karpenter (AWS side): controller IAM role + Pod Identity association,
# node IAM role + access entry, SQS interruption queue + EventBridge rules.
# The Helm chart itself is installed by Argo CD (see gitops/).
################################################################################
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = module.eks.cluster_name

  # Defaults: namespace = kube-system, service account = karpenter,
  # create_pod_identity_association = true (v21 uses Pod Identity, not IRSA)

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.name}-karpenter-node"
  node_iam_role_additional_policies = {
    # lets you open a shell on nodes with SSM Session Manager (no SSH keys)
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

################################################################################
# Pod Identity for add-ons that call AWS APIs
################################################################################
module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = ">= 1.12, < 3.0"

  name                            = "${var.name}-aws-lbc"
  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = ">= 1.12, < 3.0"

  name                      = "${var.name}-ebs-csi"
  attach_aws_ebs_csi_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = var.tags
}
