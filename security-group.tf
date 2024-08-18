# # Security Group

resource "aws_security_group" "radio_sg" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "ec2-sg"
  }
}

variable "allowed_cidr" {
  default = null
}

data "http" "ipify" {
  url = "http://api.ipify.org"
}

locals {
  myip         = chomp(data.http.ipify.body)
  allowed_cidr = (var.allowed_cidr == null) ? "${local.myip}/32" : var.allowed_cidr
}

resource "aws_security_group_rule" "in_ssh" {
  type              = "ingress"
  from_port         = 0
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.allowed_cidr]
  security_group_id = aws_security_group.radio_sg.id
}

resource "aws_security_group_rule" "out_ip_any" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.radio_sg.id
}
