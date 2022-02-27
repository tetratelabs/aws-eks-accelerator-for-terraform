variable "helm_config" {
  type        = any
  default     = {}
  description = "External DNS Helm Configuration"
}

variable "eks_cluster_id" {
  type        = string
  description = "EKS cluster Id"
}

variable "tags" {
  type        = map(string)
  description = "Common Tags for AWS resources"
}

variable "irsa_policies" {
  type        = list(string)
  description = "Additional IAM policies used for the add-on service account."
}

variable "iam_role_path" {
  type        = string
  default     = "/"
  description = "IAM role path"
}

variable "manage_via_gitops" {
  type        = bool
  default     = false
  description = "Determines if the add-on should be managed via GitOps."
}

variable "irsa_iam_permissions_boundary" {
  type        = string
  default     = ""
  description = "IAM Policy ARN for IRSA IAM role permissions boundary"
}

variable "domain_name" {
  type        = string
  description = "Domain name of the Route53 hosted zone to use with External DNS."
}
