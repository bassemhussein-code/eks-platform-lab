variable "name" {
  description = "Cluster name (used as prefix)."
  type        = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  description = "OIDC issuer without https://"
  type        = string
}

variable "namespace" {
  type    = string
  default = "demo-ambient"
}

variable "service_account" {
  type    = string
  default = "s3-reader"
}

variable "tags" {
  type    = map(string)
  default = {}
}
