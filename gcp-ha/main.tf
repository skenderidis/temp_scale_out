terraform {
  required_version = ">= 0.13"
}
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Create a random id
#
resource "random_id" "id" {
  byte_length = 2
}

# Create random password for BIG-IP
#
resource "random_string" "password" {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}
resource "google_compute_network" "mgmtvpc" {
  name                    = format("%s-mgmtvpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_network" "extvpc" {
  name                    = format("%s-extvpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_network" "intvpc" {
  name                    = format("%s-intvpc-%s", var.prefix, random_id.id.hex)
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "mgmt_subnetwork" {
  name          = format("%s-mgmt-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.1.0.0/16"
  region        = var.region
  network       = google_compute_network.mgmtvpc.id
}
resource "google_compute_subnetwork" "external_subnetwork" {
  name          = format("%s-ext-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = google_compute_network.extvpc.id
}

resource "google_compute_subnetwork" "internal_subnetwork" {
  name          = format("%s-int-%s", var.prefix, random_id.id.hex)
  ip_cidr_range = "10.3.0.0/16"
  region        = var.region
  network       = google_compute_network.intvpc.id
}

resource "google_compute_firewall" "mgmt_firewall" {
  name    = format("%s-mgmt-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.mgmtvpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "ext_firewall" {
  name    = format("%s-ext-firewall-%s", var.prefix, random_id.id.hex)
  network = google_compute_network.extvpc.id
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8443", "4353"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}


module "bigip01" {
  source              = "./modules/f5-gcp/"
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
}

module "bigip02" {
  source              = "./modules/f5-gcp/"
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
}




##  Create the DO declarations for BIGIP1

data "template_file" "tmpl_bigip1" {
  template = "${file("./templates/onboard_do_3nic_ha.tpl")}"
  vars = {
    hostname      = module.bigip01.name
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

resource "null_resource" "do_bigip1" {

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
    hostname      = module.bigip02.name
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

resource "null_resource" "do_bigip2" {

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
    command = "./do-script.sh"
    environment = {
      TF_VAR_bigip_ip  = module.bigip01.mgmtPublicIP
      TF_VAR_username  = "admin"
      TF_VAR_password  = var.f5_password
      TF_VAR_json_file = "primary-bigip.json"
      TF_VAR_prefix = "bigip01"
    }
  }
  provisioner "local-exec" {
    when    = destroy
    command = "ls -la"
    # This is where you can configure the BIGIQ revole API
  } 
  depends_on = [null_resource.do_bigip1]
}

resource "null_resource" "do_script_bigip02" {
  provisioner "local-exec" {
    command = "./do-script.sh"
    environment = {
      TF_VAR_bigip_ip  = module.bigip02.mgmtPublicIP
      TF_VAR_username  = "admin"
      TF_VAR_password  = var.f5_password
      TF_VAR_json_file = "secondary-bigip.json"
      TF_VAR_prefix = "bigip02"
    }
  }
  provisioner "local-exec" {
    when    = destroy
    command = "ls -la"
    # This is where you can configure the BIGIQ revole API
  }
    depends_on = [null_resource.do_bigip2]

}

