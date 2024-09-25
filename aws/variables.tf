variable "region" {
  default     = "eu-central-1"
  description = "AWS region"
}

variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "tf-aws-bigip"
}

variable "owner" {
  description = "Owner of VNET"
  type        = string
  default     = "Kostas"
}

variable "vpc_cidr_block" {
  description = "CIDR subnet for VNET"
  type        = string
  default     = "10.0.0.0/16"
}

variable "mgmt_cidr_block" {
  description = "F5 MGMT subnet for VNET"
  type        = string
  default     = "10.0.0.0/24"
}

variable "ext_cidr_block" {
  description = "External subnet for VNET"
  type        = string
  default     = "10.0.1.0/24"
}

variable "int_cidr_block" {
  description = "F5 Internal subnet for VNET"
  type        = string
  default     = "10.0.2.0/24"
}
variable "server_cidr_block" {
  description = "Server subnet for VNET"
  type        = string
  default     = "10.0.3.0/24"
}


variable "username" {
  description = "F5 username"
  type        = string
  default     = "kostas"
}

variable "password" {
  description = "F5 username"
  type        = string
  default     = "Kostas123"
}