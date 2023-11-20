#Create VPC
resource "aws_vpc" "two-tier-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "two-tier-vpc"
  }
}


#public subnets
resource "aws_subnet" "two-tier-public-sub-1" {
  vpc_id     = aws_vpc.two-tier-vpc.id
  cidr_block = "10.0.0.0/18"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    name = "two-tier-public-subnet-1"
  }
}

resource "aws_subnet" "two-tier-public-sub-2" {
  vpc_id     = aws_vpc.two-tier-vpc.id
  cidr_block = "10.0.128.0/18"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = "true"

  tags = {
    name = "two-tier-public-subnet-2"
  }
}

#private subnets

resource "aws_subnet" "two-tier-private-sub-1" {
  vpc_id     = aws_vpc.two-tier-vpc.id
  cidr_block = "10.0.128.0/18"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "false"

  tags = {
    name = "two-tier-private-subnet-1"
  }
}

resource "aws_subnet" "two-tier-private-sub-2" {
  vpc_id     = aws_vpc.two-tier-vpc.id
  cidr_block = "10.0.192.0/18"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = "false"

  tags = {
    name = "two-tier-private-subnet-2"
  }
}

#internet gateway

resource "aws_internet_gateway" "two-tier-igw" {
  vpc_id              = aws_vpc.two-tier-vpc.id

  tags = {
    name = "two-tier-igw"
  }
}

#route table

resource "aws_route_table" "two-tier-rt" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    name = "two-tier-rt"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.two-tier-igw
  }
}

#route table association

resource "aws_route_table_association" "two-tier-rt-as-1" {
  subnet_id      = aws_subnet.two-tier-public-sub-1
  route_table_id = aws_route_table.two-tier-rt
  }

resource "aws_route_table_association" "two-tier-rt-as-2" {
  subnet_id      = aws_subnet.two-tier-public-sub-2
  route_table_id = aws_route_table.two-tier-rt
  }

# Create Load balancer
resource "aws_lb" "two-tier-lb" {
  name               = "two-tier-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.two-tier-alb-sg.id]
  subnets            = [aws_subnet.two-tier-public-sub-1, aws_subnet.two-tier-public-sub-2]

  tags = {
    Environment = "two-tier-lb"
  }
}

resource "aws_lb_target_group" "two-tier-lb-tg" {
  name     = "two-tier-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.two-tier-vpc.id
}


# Create Load Balancer listener
resource "aws_lb_listener" "two-tier-lb-listner" {
  load_balancer_arn = aws_lb.two-tier-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.two-tier-lb-tg.arn
  }
}

# Create Target group
resource "aws_lb_target_group" "two-tier-loadb_target" {
  name       = "target"
  depends_on = [aws_vpc.two-tier-vpc]
  port       = "80"
  protocol   = "HTTP"
  vpc_id     = aws_vpc.two-tier-vpc.id
  
}

resource "aws_lb_target_group_attachment" "two-tier-tg-attch-1" {
  target_group_arn = aws_lb_target_group.two-tier-loadb_target.arn
  target_id        = aws_instance.two-tier-web-server-1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "two-tier-tg-attch-2" {
  target_group_arn = aws_lb_target_group.two-tier-loadb_target.arn
  target_id        = aws_instance.two-tier-web-server-2.id
  port             = 80
}

# Subnet group database
resource "aws_db_subnet_group" "two-tier-db-sub" {
  name       = "two-tier-db-sub"
  subnet_ids = [aws_subnet.two-tier-pvt-sub-1.id, aws_subnet.two-tier-pvt-sub-2.id]
}







resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

    ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

    ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

resource "aws_instance" "web-server" {
  ami = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c "echo its working > /var/www/html/index.html"
              EOF
  tags = {
    Nam = "web-server"
  }
}

output "server_private_ip" {
  value = aws_instance.web-server.private_ip
}