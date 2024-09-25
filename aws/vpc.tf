provider "aws" {
  region = var.region
}


resource "random_string" "suffix" {
  length  = 4
  special = false
}

################################################################################
# VPC
################################################################################


resource "aws_vpc" "main" {
  cidr_block                = var.vpc_cidr_block
  enable_dns_hostnames      = true
  enable_dns_support        = true  
  tags = {
    Name = "vpc-${var.owner}-${random_string.suffix.result}"
  }
}


################################################################################
# Subnets
################################################################################

#F5 subnets
resource "aws_subnet" "int" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.int_cidr_block
  availability_zone = "${var.region}a"
  tags = {
    Name = "F5 Internal Subnet"
  }
}

#F5 subnets
resource "aws_subnet" "ext" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.ext_cidr_block
  availability_zone = "${var.region}a"
  tags = {
    Name = "F5 External Subnet"
  }
}

#F5 subnets
resource "aws_subnet" "mgmt" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.mgmt_cidr_block
  availability_zone = "${var.region}a"
  tags = {
    Name = "F5 Mgmt Subnet"
  }
}

#F5 subnets
resource "aws_subnet" "servers" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.server_cidr_block
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Server Subnet"
  }
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "igw" {
  vpc_id     = aws_vpc.main.id
}

################################################################################
# Route Table 
################################################################################

# Public Subnets route
resource "aws_route_table" "public" {
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "Public route table"
  }
}

# Public Subnets internet gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Route Table F5 Internal
resource "aws_route_table" "f5_int" {
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "F5 Internal route table"
  }
}


################################################################################
# Associate Route Tables with Subnets
################################################################################


resource "aws_route_table_association" "mgmt" {
  subnet_id      = aws_subnet.mgmt.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "ext" {
  subnet_id      = aws_subnet.ext.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "int" {
  subnet_id      = aws_subnet.int.id
  route_table_id = aws_route_table.f5_int.id
}


resource "aws_route_table_association" "servers" {
  subnet_id      = aws_subnet.servers.id
  route_table_id = aws_route_table.public.id
}



