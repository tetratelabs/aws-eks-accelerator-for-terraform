locals {
  name                 = "ingress-nginx"
  service_account_name = "${local.name}-sa"

  default_helm_config = {
    description = "The NGINX HelmChart Ingress Controller deployment configuration"
    name        = local.name
    chart       = local.name
    repository  = "https://kubernetes.github.io/ingress-nginx"
    version     = "4.0.6"
    namespace   = local.name
    values      = local.default_helm_values
    timeout     = "1200"
  }

  default_helm_values = [templatefile("${path.module}/values.yaml", {
    service_account_name = local.service_account_name
  })]

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  argocd_gitops_config = {
    enable             = true
    serviceAccountName = local.service_account_name
  }

  irsa_config = {
    kubernetes_namespace              = local.name
    kubernetes_service_account        = local.service_account_name
    create_kubernetes_namespace       = true
    create_kubernetes_service_account = true
    iam_role_path                     = "/"
    eks_cluster_id                    = var.eks_cluster_id
    irsa_iam_policies                 = concat([aws_iam_policy.this.arn], var.irsa_policies)
    irsa_iam_permissions_boundary     = var.irsa_iam_permissions_boundary
    tags                              = var.tags
  }

  set_values = [
    {
      name  = "serviceAccount.name"
      value = local.service_account_name
    },
    {
      name  = "serviceAccount.create"
      value = false
    }
  ]
}
