variable "name" {
  description = "Name prefix (also the EKS cluster name, used in discovery tags)."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all AZs (cheaper, not HA)."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
