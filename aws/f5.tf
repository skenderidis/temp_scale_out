resource "aws_key_pair" "f5" {
  key_name   = "f5-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqDTxbQUK1GC4u0JMMMUHNJ1+6j7hgoQo6q3HI85NhxyFAWttEWvzgVeLcNfNzEkQ05eIExJSGQbK24a9WD1E1F7fEedkwMNgCSEPnDUkPb4YnP0UTpgLSxuCmhfEy5IBbM42RdBQ+Pxi+PzmgfcoPa6QE6fKbBBuW9dip9EwKvWmZLj7YPweJf1hR71nVBTLy1h8JYbbM97364rowgRGAcKTKc2mCb//JnI/MTmXBfvoU1qWYldJXFXok0n4QRQj6yvzbSguDILkKHU3o36G3KazyfmHmYIpqYSMr7WPpVoGnI4EXyZQt40bipy0R1OZusO6CiMIuwRUoVls2p459 k.skenderidis@f5.com"
}


module bigip_ha_1 {
  source                      = "F5Networks/bigip-module/aws"
  prefix                      = "bigip-01"
  ec2_key_name                = aws_key_pair.f5.key_name
  mgmt_subnet_ids             = [{ "subnet_id" = aws_subnet.mgmt.id, "public_ip" = true, "private_ip_primary" =  "10.0.0.20"}]
  mgmt_securitygroup_ids      = [aws_security_group.mgmt.id]
  external_subnet_ids         = [{ "subnet_id" = aws_subnet.ext.id, "public_ip" = true, "private_ip_primary" = "10.0.1.20", "private_ip_secondary" = "10.0.1.50"}]
  external_securitygroup_ids  = [aws_security_group.ext.id]
  internal_subnet_ids         = [{"subnet_id" =  aws_subnet.int.id, "public_ip"=false, "private_ip_primary" = "10.0.2.20"}]
  internal_securitygroup_ids  = [aws_security_group.int.id]
  sleep_time                  = "420s"
  custom_user_data = templatefile("templates/f5_onboard.tmpl", {
    bigip_username         = var.username
    ssh_keypair            = file("~/.ssh/id_rsa.pub")
    aws_secretmanager_auth = false
    bigip_password         = var.password
    INIT_URL               = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.45.0/f5-declarative-onboarding-1.45.0-6.noarch.rpm",
    DO_VER                 = "v1.45.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.52.0/f5-appsvcs-3.52.0-5.noarch.rpm",
    AS3_VER                = "v3.52.0"
  })
}


module bigip_ha_2 {
  source                      = "F5Networks/bigip-module/aws"
  prefix                      = "bigip-02"
  ec2_key_name                = aws_key_pair.f5.key_name
  mgmt_subnet_ids             = [{ "subnet_id" = aws_subnet.mgmt.id, "public_ip" = true, "private_ip_primary" =  "10.0.0.21"}]
  mgmt_securitygroup_ids      = [aws_security_group.mgmt.id]
  external_subnet_ids         = [{ "subnet_id" = aws_subnet.ext.id, "public_ip" = true, "private_ip_primary" = "10.0.1.21", "private_ip_secondary" = "10.0.1.51"}]
  external_securitygroup_ids  = [aws_security_group.ext.id]
  internal_subnet_ids         = [{"subnet_id" =  aws_subnet.int.id, "public_ip"=false, "private_ip_primary" = "10.0.2.21"}]
  internal_securitygroup_ids  = [aws_security_group.int.id]
  sleep_time                  = "420s"
  custom_user_data = templatefile("templates/f5_onboard.tmpl", {
    bigip_username         = var.username
    ssh_keypair            = file("~/.ssh/id_rsa.pub")
    aws_secretmanager_auth = false
    bigip_password         = var.password
    INIT_URL               = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",
    DO_URL                 = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.45.0/f5-declarative-onboarding-1.45.0-6.noarch.rpm",
    DO_VER                 = "v1.45.0"
    AS3_URL                = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.52.0/f5-appsvcs-3.52.0-5.noarch.rpm",
    AS3_VER                = "v3.52.0"
  })
}



data "template_file" "tmpl_bigip1" {
  template = "${file("./templates/onboard_do_3nic_ha.tpl")}"
  vars = {
    hostname      = module.bigip_ha_1.mgmtPublicDNS
    primary       = "10.0.1.20"
    secondary     = "10.0.1.21"
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.253"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.213"]))
    vlan-name1    = "external"
    self-ip1      = "10.0.1.20"
    vlan-name2    = "internal"
    self-ip2      = "10.0.2.20"
    password      = var.password
    gateway       = join(".", concat(slice(split(".", "10.0.1.0/24"), 0, 3), [1]))
  }
  depends_on = [module.bigip_ha_1]
}


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
    hostname      = module.bigip_ha_2.mgmtPublicDNS
    primary       = "10.0.1.20"
    secondary     = "10.0.1.21"
    name_servers  = join(",", formatlist("\"%s\"", ["169.254.169.253"]))
    search_domain = "f5.com"
    ntp_servers   = join(",", formatlist("\"%s\"", ["169.254.169.213"]))
    vlan-name1    = "external"
    self-ip1      = "10.0.1.21"
    vlan-name2    = "internal"
    self-ip2      = "10.0.2.21"
    password      = var.password
    gateway       = join(".", concat(slice(split(".", "10.0.1.0/24"), 0, 3), [1]))
  }
  depends_on = [module.bigip_ha_2]
}


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
      TF_VAR_bigip_ip  = module.bigip_ha_1.mgmtPublicDNS
      TF_VAR_username  = "admin"
      TF_VAR_password  = var.password
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
      TF_VAR_bigip_ip  = module.bigip_ha_2.mgmtPublicDNS
      TF_VAR_username  = "admin"
      TF_VAR_password  = var.password
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

