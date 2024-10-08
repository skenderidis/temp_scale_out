variable "prefix" {
  description = "Prefix for resources created by this module"
  type        = string
  default     = "tf-gcp-bigip"
}

variable "project_id" {
  type        = string
  description = "The GCP project identifier where the cluster will be created."
}

variable "region" {
  type        = string
  description = "The compute region which will host the BIG-IP VMs"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "The compute zones which will host the BIG-IP VMs"
}

variable "image" {
  type        = string
  default     = "projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-4-0-0-9-payg-best-25mbps-240902165628"
  description = "The self-link URI for a BIG-IP image to use as a base for the VM cluster.This can be an official F5 image from GCP Marketplace, or a customised image."
}

variable "service_account" {
  description = "service account email to use with BIG-IP vms"
  type        = string
}

variable "f5_password" {
  description = "service account email to use with BIG-IP vms"
  type        = string
  default     = "Thisisthepassword123"
}


variable "f5_username" {
  description = "service account email to use with BIG-IP vms"
  type        = string
  default     = "gcp_user"
}

variable "scale_out" {
  default     = 0
}

