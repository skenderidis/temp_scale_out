resource "aws_security_group" "mgmt" {
  name        = "F5 Management SG"
  description = "Allow TLS inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress = [
    {
        description      = "Allow 443"
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        ipv6_cidr_blocks = null
        prefix_list_ids  = null
        security_groups  = null
        self             = null
        cidr_blocks      = ["0.0.0.0/0"]

    },
     {
        description      = "Allow 8443"
        from_port        = 8443
        to_port          = 8443
        protocol         = "tcp"
        ipv6_cidr_blocks = null
        prefix_list_ids  = null
        security_groups  = null
        self             = null      
        cidr_blocks      = ["0.0.0.0/0"]
    },
     {
        description      = "Allow 22"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        ipv6_cidr_blocks = null
        prefix_list_ids  = null
        security_groups  = null
        self             = null      
        cidr_blocks      = ["0.0.0.0/0"]
    }          
  ]

  egress = [
    {
        description      = "Allow All"
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        ipv6_cidr_blocks = null
        prefix_list_ids  = null
        security_groups  = null
        self             = null
        cidr_blocks      = ["0.0.0.0/0"]
    }
  ]

  tags = {
    Name = "F5 Management SG"
  }
}


resource "aws_security_group" "ext" {
  name        = "F5 Ext SG"
  description = "Allow TLS inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress = [
    {
        description      = "Allow 443"
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        ipv6_cidr_blocks = null
        prefix_list_ids  = null
        security_groups  = null
        self             = null
        cidr_blocks      = ["0.0.0.0/0"]

    },
     {
        description      = "Allow 80"
        from_port        = 80
        to_port          = 80
        protocol         = "tcp"
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups = null
        self            = null      
        cidr_blocks      = ["0.0.0.0/0"]
    },
     {
        description      = "Allow ICMP"
        from_port = -1
        to_port = -1
        protocol         = "icmp"
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups = null
        self            = null      
        cidr_blocks      = ["0.0.0.0/0"]
    },
    {
      description      = "Allow 4353"
      from_port        = 4353
      to_port          = 4353
      protocol         = "tcp"
      ipv6_cidr_blocks = null
      prefix_list_ids = null
      security_groups = null
      self            = null      
      cidr_blocks      = ["10.0.0.0/8"]
  }
  ]

  egress = [
    {
        description      = "Allow All"
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups =null
        self = null
        cidr_blocks      = ["0.0.0.0/0"]
    }
  ]

  tags = {
    Name = "F5 External SG"
  }
}


resource "aws_security_group" "int" {
  name        = "Worker_Nodes_SG"
  description = "Allow private subnets to communicate with EKS Pods/Nodes and F5 Internal subnets"
  #  name_prefix = "all_worker_management"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"

    cidr_blocks      = ["0.0.0.0/0"]

  }
  egress = [
    {
        description      = "Allow All"
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups =null
        self = null
        cidr_blocks      = ["0.0.0.0/0"]
    }
  ]  

  tags = {
    Name = "All Internal communication"
  }

}

