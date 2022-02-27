locals {
  name                 = "external-dns"
  service_account_name = "${local.name}-sa"
  zone_filter_ids      = jsonencode([data.aws_route53_zone.selected.zone_id])

  default_helm_values = [templatefile("${path.module}/values.yaml", {
    aws_region           = data.aws_region.current.name
    zone_filter_ids      = local.zone_filter_ids
    service_account_name = local.service_account_name
  })]

  default_helm_config = {
    description = "Argo Rollouts AddOn Helm Chart"
    name        = local.name
    chart       = local.name
    repository  = "https://charts.bitnami.com/bitnami"
    version     = "5.5.0"
    namespace   = local.name
    values      = local.default_helm_values
    timeout     = "1200"
  }

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  argocd_gitops_config = {
    enable            = true
    zoneFilterIds     = local.zone_filter_ids
    serviceAccontName = local.service_account_name
  }

  irsa_config = {
    kubernetes_namespace              = local.name
    kubernetes_service_account        = local.service_account_name
    create_kubernetes_namespace       = true
    create_kubernetes_service_account = true
    iam_role_path                     = "/"
    eks_cluster_id                    = var.eks_cluster_id
    irsa_iam_policies                 = concat([aws_iam_policy.external_dns.arn], var.irsa_policies)
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
