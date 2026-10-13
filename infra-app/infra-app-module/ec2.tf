resource "aws_key_pair" "my_key" {
  key_name   = "${var.env}-terra-key-ec2"
  public_key = file("${path.module}/../../.env/terra-key-ec2.pub")
}

resource "aws_default_vpc" "infra-app-default_vpc" {

}

resource "aws_security_group" "infra-app-sg" {
  name        = "${var.env}-infra-app-sg"
  description = "Allow user to connect"
  vpc_id      = aws_default_vpc.infra-app-default_vpc.id
  tags = {
    name = "${var.env}-infra-app-sg"
    environment = var.env
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.infra-app-sg.id
  to_port   = 22
  from_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.infra-app-sg.id
  to_port   = 80
  from_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound" {
  security_group_id = aws_security_group.infra-app-sg.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_instance" "infra-app-ec2" {
  
  count = var.instance_count
  key_name = aws_key_pair.my_key.key_name
  security_groups = [ aws_security_group.infra-app-sg.name ]
  instance_type = var.instance_type
  ami = var.ami_id

  root_block_device {
    volume_size = var.ec2_root_storage
    volume_type = "gp3"
  }
  tags = {
    name = "${var.env}-infra-app-ec2"
    environment = var.env
  }
}

