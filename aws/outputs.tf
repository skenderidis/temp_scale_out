# BIG-IP Management Public DNS Address
output "mgmtPublicIP_01" {
  value = module.bigip_ha_1.mgmtPublicDNS
}
output "mgmtPublicIP_02" {
  value = module.bigip_ha_2.mgmtPublicDNS
}


# OUTPUT
output "aws_instance_public_dns" {
  value = aws_instance.web.public_dns
}

# VPC ID used for BIG-IP Deploy
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_addresses_1" {
  description = "List of BIG-IP private addresses"
  value       = module.bigip_ha_1.*.private_addresses
}

output "private_addresses_2" {
  description = "List of BIG-IP private addresses"
  value       = module.bigip_ha_2.*.private_addresses
}


output "subnet_mgmt" {
  description = "List of BIG-IP private addresses"
  value       = aws_subnet.mgmt.id
}

output "subnet_ext" {
  description = "List of BIG-IP private addresses"
  value       = aws_subnet.ext.id
}

output "subnet_int" {
  description = "List of BIG-IP private addresses"
  value       = aws_subnet.int.id
}

output "sg_mgmt" {
  description = "List of BIG-IP private addresses"
  value       = aws_security_group.mgmt.id
}

output "sg_ext" {
  description = "List of BIG-IP private addresses"
  value       = aws_security_group.ext.id
}

output "sg_int" {
  description = "List of BIG-IP private addresses"
  value       = aws_security_group.int.id
}
