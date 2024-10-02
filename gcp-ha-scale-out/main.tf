terraform {
  required_version = ">= 0.13"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "terraform_remote_state" "ha" {
  backend = "local"

  config = {
    path = "../gcp-ha/terraform.tfstate"
  }
}



# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}


module "bigip03" {
  count = var.scale_out >= 1 ? 1 : 0 
  source              = "./modules/f5-gcp/"
  prefix              = format("%s-3nic-scale-out", var.prefix)
  project_id          = var.project_id
  zone                = var.zone
  image               = var.image
  service_account     = var.service_account
  f5_password         = var.f5_password
  sleep_time          = "10s"
  mgmt_subnet_ids     = [{ "subnet_id" = data.terraform_remote_state.ha.outputs.mgmt_subnetwork, "public_ip" = true, "private_ip_primary" = "10.1.0.12" }]
  external_subnet_ids = [{ "subnet_id" = data.terraform_remote_state.ha.outputs.external_subnetwork, "public_ip" = false, "private_ip_primary" = "10.2.0.12", "private_ip_secondary" = "10.2.0.22" }]
  internal_subnet_ids = [{ "subnet_id" = data.terraform_remote_state.ha.outputs.internal_subnetwork, "public_ip" = false, "private_ip_primary" = "10.3.0.12", "private_ip_secondary" = "10.3.0.22" }]
  custom_user_data = templatefile("templates/startup-script.tpl", {
    hostname               = "bigip03.local"
    bigip_username         = "kostas"
    ssh_keypair            = file("~/.ssh/id_rsa.pub")
    gcp_secret_manager_authentication = false
    bigip_password         = "Kostas123"
    INIT_URL               = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.45.0/f5-declarative-onboarding-1.45.0-6.noarch.rpm",
    DO_VER                 = "v1.45.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.52.0/f5-appsvcs-3.52.0-5.noarch.rpm",
    AS3_VER                = "v3.52.0"
    self_ip_ext            = "10.2.0.12"
    self_ip_int            = "10.3.0.12"
    ext_cidr_range         = "10.2.0.0/16"
    NIC_COUNT              = true
    gateway                = join(".", concat(slice(split(".", "10.2.0.0/16"), 0, 3), [1]))
  })


}

module "bigip04" {
  count = var.scale_out >= 2 ? 1 : 0 
  source              = "./modules/f5-gcp/"
  prefix              = format("%s-3nic-scale-out", var.prefix)
  project_id          = var.project_id
  zone                = var.zone
  image               = var.image
  service_account     = var.service_account
  f5_password         = var.f5_password
  sleep_time          = "10s"
  mgmt_subnet_ids     = [{ "subnet_id" = data.terraform_remote_state.ha.outputs.mgmt_subnetwork, "public_ip" = true, "private_ip_primary" = "10.1.0.13" }]
  external_subnet_ids = [{ "subnet_id" = data.terraform_remote_state.ha.outputs.external_subnetwork, "public_ip" = false, "private_ip_primary" = "10.2.0.13", "private_ip_secondary" = "10.2.0.23" }]
  internal_subnet_ids = [{ "subnet_id" = data.terraform_remote_state.ha.outputs.internal_subnetwork, "public_ip" = false, "private_ip_primary" = "10.3.0.13", "private_ip_secondary" = "10.3.0.23" }]
  custom_user_data = templatefile("templates/startup-script.tpl", {
    hostname               = "bigip04.local"
    bigip_username         = "kostas"
    ssh_keypair            = file("~/.ssh/id_rsa.pub")
    gcp_secret_manager_authentication = false
    bigip_password         = "Kostas123"
    INIT_URL               = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.45.0/f5-declarative-onboarding-1.45.0-6.noarch.rpm",
    DO_VER                 = "v1.45.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.52.0/f5-appsvcs-3.52.0-5.noarch.rpm",
    AS3_VER                = "v3.52.0"
    self_ip_ext            = "10.2.0.13"
    self_ip_int            = "10.3.0.13"
    NIC_COUNT              = true
    gateway                = join(".", concat(slice(split(".", "10.2.0.0/16"), 0, 3), [1]))
  })
}




resource "null_resource" "add_bigip03_to_cluster" {
  count = var.scale_out >= 1 ? 1 : 0   
  triggers = {
    bigip_01_ip        = data.terraform_remote_state.ha.outputs.mgmtPublicIP_BIGIP01           # This will be used to reach (from Terraform) the primary appliance and run the API requests
    bigip_01_name      = data.terraform_remote_state.ha.outputs.Name_BIGIP01         # This will be used for the HA Failover Group
    bigip_02_name      = data.terraform_remote_state.ha.outputs.Name_BIGIP02         # This will be used for the HA Failover Group
    bigip_03_ip        = "10.2.0.12"                                                # This will be used to add device to trust
    password          = var.f5_password           # The F5 Device password
  }

  # Append the entry on create
  provisioner "local-exec" {
    when    = create
    command = "./add_bigip03_to_cluster.sh"
    environment = {
      primary_bigip  = "${self.triggers.bigip_01_ip}"            # Will be used to reach to the primary appliance and run the API requests
      bigip_01_name  = "${self.triggers.bigip_01_name}"          # This will be used for the HA Failover Group
      bigip_02_name  = "${self.triggers.bigip_02_name}"          # This will be used for the HA Failover Group
      bigip_03_name  = "${self.triggers.bigip_03_ip}"             # For the device name we will use the IP address of the external interface
      f5_password    = "${self.triggers.password}"               # The F5 Device password
    }
  }


  provisioner "local-exec" {
    when    = destroy
    command = "./remove_bigip03_from_cluster.sh"
    environment = {
      primary_bigip  = "${self.triggers.bigip_01_ip}"            # Will be used to reach to the primary appliance and run the API requests
      bigip_01_name  = "${self.triggers.bigip_01_name}"          # This will be used for the HA Failover Group
      bigip_02_name  = "${self.triggers.bigip_02_name}"          # This will be used for the HA Failover Group
      bigip_03_name  = "${self.triggers.bigip_03_ip}"             # For the device name we will use the IP address of the external interface
      f5_password    = "${self.triggers.password}"               # The F5 Device password
    }
  }

  depends_on = [module.bigip03, module.bigip04]
}


resource "null_resource" "add_bigip04_to_cluster" {
  count = var.scale_out >= 2 ? 1 : 0   
  triggers = {
    bigip_01_ip        = data.terraform_remote_state.ha.outputs.mgmtPublicIP_BIGIP01           # This will be used to reach (from Terraform) the primary appliance and run the API requests
    bigip_01_name      = data.terraform_remote_state.ha.outputs.Name_BIGIP01         # This will be used for the HA Failover Group
    bigip_02_name      = data.terraform_remote_state.ha.outputs.Name_BIGIP02         # This will be used for the HA Failover Group
    bigip_03_ip        = "10.2.0.12"                                                # This will be used to add device to trust
    bigip_04_ip        = "10.2.0.13"                                                # This will be used to add device to trust
    password          = var.f5_password           # The F5 Device password
  }

  # Append the entry on create
  provisioner "local-exec" {
    when    = create
    command = "./add_bigip04_to_cluster.sh"
    environment = {
      primary_bigip  = "${self.triggers.bigip_01_ip}"            # Will be used to reach to the primary appliance and run the API requests
      bigip_01_name  = "${self.triggers.bigip_01_name}"          # This will be used for the HA Failover Group
      bigip_02_name  = "${self.triggers.bigip_02_name}"          # This will be used for the HA Failover Group
      bigip_03_name  = "${self.triggers.bigip_03_ip}"             # For the device name we will use the IP address of the external interface
      bigip_04_name  = "${self.triggers.bigip_04_ip}"             # For the device name we will use the IP address of the external interface
      f5_password    = "${self.triggers.password}"               # The F5 Device password
    }
  }


  provisioner "local-exec" {
    when    = destroy
    command = "./remove_bigip04_from_cluster.sh"
    environment = {
      primary_bigip  = "${self.triggers.bigip_01_ip}"            # Will be used to reach to the primary appliance and run the API requests
      bigip_01_name  = "${self.triggers.bigip_01_name}"          # This will be used for the HA Failover Group
      bigip_02_name  = "${self.triggers.bigip_02_name}"          # This will be used for the HA Failover Group
      bigip_03_name  = "${self.triggers.bigip_03_ip}"             # For the device name we will use the IP address of the external interface
      bigip_04_name  = "${self.triggers.bigip_04_ip}"             # For the device name we will use the IP address of the external interface
      f5_password    = "${self.triggers.password}"               # The F5 Device password
    }
  }

  depends_on = [module.bigip03, module.bigip04]
}

