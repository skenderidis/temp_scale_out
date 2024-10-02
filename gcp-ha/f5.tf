module "bigip01" {
  source              = "F5Networks/bigip-module/gcp"
  prefix              = format("%s-3nic", var.prefix)
  project_id          = var.project_id
  zone                = var.zone
  image               = var.image
  service_account     = var.service_account
  f5_password         = var.f5_password
  sleep_time          = "600s"
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "10.1.0.10" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.external_subnetwork.id, "public_ip" = false, "private_ip_primary" = "10.2.0.10", "private_ip_secondary" = "10.2.0.20" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.internal_subnetwork.id, "public_ip" = false, "private_ip_primary" = "10.3.0.10", "private_ip_secondary" = "10.3.0.20" }]
  custom_user_data = templatefile("templates/startup-script.tpl", {
    hostname               = var.primary_bigip_name
    bigip_username         = var.f5_username
    ssh_keypair            = file("~/.ssh/id_rsa.pub")
    gcp_secret_manager_authentication = false
    bigip_password         = var.f5_password
    INIT_URL               = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.45.0/f5-declarative-onboarding-1.45.0-6.noarch.rpm",
    DO_VER                 = "v1.45.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.52.0/f5-appsvcs-3.52.0-5.noarch.rpm",
    AS3_VER                = "v3.52.0"
    NIC_COUNT              = true
  })
}

module "bigip02" {
  source              = "F5Networks/bigip-module/gcp"
  prefix              = format("%s-3nic", var.prefix)
  project_id          = var.project_id
  zone                = var.zone
  image               = var.image
  service_account     = var.service_account
  f5_password         = var.f5_password
  sleep_time          = "600s"
  mgmt_subnet_ids     = [{ "subnet_id" = google_compute_subnetwork.mgmt_subnetwork.id, "public_ip" = true, "private_ip_primary" = "10.1.0.11" }]
  external_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.external_subnetwork.id, "public_ip" = false, "private_ip_primary" = "10.2.0.11", "private_ip_secondary" = "10.2.0.21" }]
  internal_subnet_ids = [{ "subnet_id" = google_compute_subnetwork.internal_subnetwork.id, "public_ip" = false, "private_ip_primary" = "10.3.0.11", "private_ip_secondary" = "10.3.0.21" }]
  custom_user_data = templatefile("templates/startup-script.tpl", {
    hostname               = var.secondary_bigip_name
    bigip_username         = var.f5_username
    ssh_keypair            = file("~/.ssh/id_rsa.pub")
    gcp_secret_manager_authentication = false
    bigip_password         = var.f5_password
    INIT_URL               = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.45.0/f5-declarative-onboarding-1.45.0-6.noarch.rpm",
    DO_VER                 = "v1.45.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.52.0/f5-appsvcs-3.52.0-5.noarch.rpm",
    AS3_VER                = "v3.52.0"
    NIC_COUNT              = true
  })
}


##  Create the DO declarations for BIGIP1

data "template_file" "tmpl_bigip1" {
  template = "${file("./templates/onboard_do_3nic_ha.tpl")}"
  vars = {
    hostname      = var.primary_bigip_name
    primary       = "10.2.0.10"
    secondary     = "10.2.0.11"
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.254"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.254"]))
    vlan-name1    = "external"
    self-ip1      = "10.2.0.10"
    vlan-name2    = "internal"
    self-ip2      = "10.3.0.10"
    password      = var.f5_password
    gateway       = join(".", concat(slice(split(".", "10.2.0.0/16"), 0, 3), [1]))
    ext_cidr_range = "10.2.0.0/16"    
  }
  depends_on = [module.bigip01, module.bigip02]
}

# Save declaration to file for the primary device

resource "null_resource" "do_template_bigip1" {

  provisioner "local-exec" {
    command = "cat > primary-bigip.json <<EOL\n ${data.template_file.tmpl_bigip1.rendered}\nEOL"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf primary-bigip.json"
  }
}


data "template_file" "tmpl_bigip2" {
  template = "${file("./templates/onboard_do_3nic_ha.tpl")}"
  vars = {
    hostname      = var.secondary_bigip_name
    primary       = "10.2.0.10"
    secondary     = "10.2.0.11"
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.254"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.254"]))
    vlan-name1    = "external"
    self-ip1      = "10.2.0.11"
    vlan-name2    = "internal"
    self-ip2      = "10.3.0.11"
    password      = var.f5_password
    gateway       = join(".", concat(slice(split(".", "10.2.0.0/24"), 0, 3), [1]))
    ext_cidr_range = "10.2.0.0/16"
  }
  depends_on = [module.bigip02, module.bigip01 ]
}

# Save declaration to file for the secondary device

resource "null_resource" "do_template_bigip2" {

  provisioner "local-exec" {
    command = "cat > secondary-bigip.json <<EOL\n ${data.template_file.tmpl_bigip2.rendered}\nEOL"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf secondary-bigip.json"
  }
}



####  Deploy DO with Bash script

resource "null_resource" "do_script_bigip01" {
  provisioner "local-exec" {
    when    = create
    command = "./do-script.sh"
    environment = {
      TF_VAR_bigip_ip  = module.bigip01.mgmtPublicIP
      TF_VAR_username  = "admin"
      TF_VAR_password  = var.f5_password
      TF_VAR_json_file = "primary-bigip.json"
      TF_VAR_prefix = "bigip01"
    }
  }

  depends_on = [null_resource.do_template_bigip1]
}

resource "null_resource" "do_script_bigip02" {
  provisioner "local-exec" {
    when    = create
    command = "./do-script.sh"
    environment = {
      TF_VAR_bigip_ip  = module.bigip02.mgmtPublicIP
      TF_VAR_username  = "admin"
      TF_VAR_password  = var.f5_password
      TF_VAR_json_file = "secondary-bigip.json"
      TF_VAR_prefix = "bigip02"
    }
  }

    depends_on = [null_resource.do_template_bigip2]

}

