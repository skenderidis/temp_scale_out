output "mgmtPublicIP_BIGIP03" {
  value = module.bigip03.*.mgmtPublicIP
}

output "Name_BIGIP03" {
  value = module.bigip03.*.name
}

output "mgmtPublicIP_BIGIP04" {
  value = module.bigip04.*.mgmtPublicIP
}

output "Name_BIGIP04" {
  value = module.bigip04.*.name
}
