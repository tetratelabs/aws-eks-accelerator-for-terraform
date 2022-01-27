
locals {
  namespace            = "external-dns"
  service_account_name = "external-dns-sa"

  zone_filter_arns = [data.aws_route53_zone.selected.arn]
  zone_filter_ids  = [data.aws_route53_zone.selected.zone_id]

  default_helm_config = {
    name                       = "external-dns"
    chart                      = "external-dns"
    description                = "External DNS Helm Chart deployment configuration.s"
    repository                 = "https://charts.bitnami.com/bitnami"
    version                    = "5.1.3"
    namespace                  = local.namespace
    timeout                    = "1200"
    create_namespace           = true
    values                     = local.default_helm_values
    set                        = []
    set_sensitive              = null
    lint                       = true
    wait                       = true
    wait_for_jobs              = false
    verify                     = false
    keyring                    = ""
    repository_key_file        = ""
    repository_cert_file       = ""
    repository_ca_file         = ""
    repository_username        = ""
    repository_password        = ""
    disable_webhooks           = false
    reuse_values               = false
    reset_values               = false
    force_update               = false
    recreate_pods              = false
    cleanup_on_fail            = false
    max_history                = 0
    atomic                     = false
    skip_crds                  = false
    render_subchart_notes      = true
    disable_openapi_validation = false
    dependency_update          = false
    replace                    = false
    postrender                 = ""
  }

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  default_helm_values = [templatefile("${path.module}/values.yaml", {
    aws_region           = data.aws_region.current.name
    zone_filter_ids      = jsonencode(local.zone_filter_ids)
    service_account_name = local.service_account_name
  })]

  argocd_gitops_config = {
    enable            = true
    zoneFilterIds     = jsonencode(local.zone_filter_ids)
    serviceAccontName = local.service_account_name
  }
}
