# Get latest Ubuntu Linux Disco 20.04 AMI
data "aws_ami" "nginx" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the Linux EC2 Web server
resource "aws_instance" "web" {
 ami = data.aws_ami.nginx.id
 instance_type = "t2.micro"
 key_name = aws_key_pair.f5.id
 subnet_id = aws_subnet.servers.id
 security_groups = [aws_security_group.ext.id]
user_data = <<-EOF
 #!/bin/bash
  sudo apt update -y &&
  sudo apt install -y nginx
EOF
}




