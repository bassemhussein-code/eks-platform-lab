variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. Upgrade ONE minor at a time."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Set to your own IP /32."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_principal_arns" {
  description = "Extra IAM role/user ARNs that get cluster-admin via access entries."
  type        = list(string)
  default     = []
}

variable "system_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
