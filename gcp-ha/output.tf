output "mgmtPublicIP_BIGIP01" {
  value = module.bigip01.mgmtPublicIP
}

output "Name_BIGIP01" {
  value = var.primary_bigip_name
}

output "mgmtPublicIP_BIGIP02" {
  value = module.bigip02.mgmtPublicIP
}

output "Name_BIGIP02" {
  value = var.secondary_bigip_name
}



output "mgmt_subnetwork" {
  value = google_compute_subnetwork.mgmt_subnetwork.id
}
output "external_subnetwork" {
  value = google_compute_subnetwork.external_subnetwork.id
}
output "internal_subnetwork" {
  value = google_compute_subnetwork.internal_subnetwork.id
}
