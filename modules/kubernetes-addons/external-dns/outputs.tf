output "service_account_name" {
  description = "Service account name for the add-on"
  value       = local.service_account_name
}

output "zone_filter_ids" {
  description = "Zone Filter Ids for the add-on"
  value       = local.zone_filter_ids
}

output "argocd_gitops_config" {
  description = "Configuration used for managing the add-on with GitOps"
  value       = var.manage_via_gitops ? local.argocd_gitops_config : null
}
