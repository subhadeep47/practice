resource "aws_key_pair" "my_key" {
  key_name   = "terra-key-ec2"
  public_key = file("../.env/terra-key-ec2.pub")
}

resource "aws_default_vpc" "default_vpc" {

}

resource "aws_security_group" "my_sg" {
  name        = "terraform-sg"
  description = "this SG will be created by terraform"
  vpc_id      = aws_default_vpc.default_vpc.id # Through interpolation

  tags = {
    name = "terraform-learn"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.my_sg.id
  to_port   = 22
  from_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.my_sg.id
  to_port   = 80
  from_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_my_app" {
  security_group_id = aws_security_group.my_sg.id
  to_port   = 8080
  from_port = 8080
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound" {
  security_group_id = aws_security_group.my_sg.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_instance" "my_ec2" {
  key_name = aws_key_pair.my_key.key_name
  security_groups = [ aws_security_group.my_sg.name ]
  instance_type = "t3.micro"
  ami = "ami-0aba19e56f3eaec05" #ubuntu
  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }
  tags = {
    name = "terraform-learn"
  }
}

