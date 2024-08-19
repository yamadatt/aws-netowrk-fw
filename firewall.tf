variable "http_permit_ips" {
  default = [
    # "133.203.185.64/32",
    "1.1.1.1/32",
    "8.8.8.8/32"
  ]
}

# Network Firewall Segment
resource "aws_subnet" "subnet_firewall_a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.0.0.0/24"

  tags = {
    Name = "subnet-firewall-a"
  }
}


resource "aws_networkfirewall_rule_group" "ips" {
  capacity = 100
  name     = "example"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["TLS_SNI", "HTTP_HOST"]
        targets              = ["yamada-tech-memo.netlify.app"]
      }
    }
  }
  #   capacity = 100
  #   name     = "ips"
  #   type     = "STATEFUL"
  #   #rules    = file("${path.module}/rules/sample-rules.txt")
  #   rule_group {
  #     rules_source {
  #       rules_string = file("./sample-suricata-rules.txt")
  #     }
  #     rule_variables {
  #       ip_sets {
  #         key = "EXTERNAL_NET"
  #         ip_set {
  #           definition = ["0.0.0.0/0"]
  #         }
  #       }

  #       ip_sets {
  #         key = "HOME_NET"
  #         ip_set {
  #           definition = [var.vpc_cidr]
  #         }
  #       }
  #       ip_sets {
  #         key = "HTTP_NET"
  #         ip_set {
  #           definition = ["${aws_instance.raido-rec.public_ip}/32"]
  #         }
  #       }

  #       ip_sets {
  #         key = "HTTP_PERMIT_NET"

  #         ip_set {
  #           definition = var.http_permit_ips
  #         }
  #       }
  #       port_sets {
  #         key = "HTTP_PORTS"
  #         port_set {
  #           #definition = ["[80,443]"]
  #           definition = ["80", "443"]
  #         }
  #       }
  #     }
  #   }
  tags = {
    Name = "nwfw-rules-ips"
  }
}


resource "aws_networkfirewall_firewall_policy" "firewall" {
  name = "firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.ips.arn
    }
  }

  tags = {
    Name = "subnet-firewall-initial-policy"
  }
}


resource "aws_networkfirewall_firewall" "firewall" {
  name                = "firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.firewall.arn
  vpc_id              = aws_vpc.vpc.id

  subnet_mapping {
    subnet_id = aws_subnet.subnet_firewall_a.id
  }


  tags = {
    Name = "firewall"
  }
}


resource "aws_s3_bucket" "nwfw_logs" {
  bucket        = "yamada-fw-logs"
  force_destroy = true
}

resource "aws_networkfirewall_logging_configuration" "firewall" {
  firewall_arn = aws_networkfirewall_firewall.firewall.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        bucketName = aws_s3_bucket.nwfw_logs.bucket
        prefix     = "nwfw"
      }
      log_destination_type = "S3"
      log_type             = "ALERT"
    }

  }
}

## igwからのルートテーブル

resource "aws_route_table" "rtb_igw" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block      = aws_subnet.public_subnet_1a.cidr_block
    vpc_endpoint_id = element([for ss in tolist(aws_networkfirewall_firewall.firewall.firewall_status[0].sync_states) : ss.attachment[0].endpoint_id if ss.attachment[0].subnet_id == aws_subnet.subnet_firewall_a.id], 0)
  }
  tags = {
    Name = "rtb-igw"
  }
}

resource "aws_route_table_association" "rtb_assoc_igw" {
  gateway_id     = aws_internet_gateway.igw.id
  route_table_id = aws_route_table.rtb_igw.id
}


resource "aws_route_table" "rtb_firewall" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rtb-firewall"
  }
}

resource "aws_route_table_association" "rtb_assoc_firewall_a" {
  route_table_id = aws_route_table.rtb_firewall.id
  subnet_id      = aws_subnet.subnet_firewall_a.id
}


# Route Table(Public)

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "public-route"
  }
}

resource "aws_route" "to_internet" {
  route_table_id  = aws_route_table.public_rt.id
  vpc_endpoint_id = element([for ss in tolist(aws_networkfirewall_firewall.firewall.firewall_status[0].sync_states) : ss.attachment[0].endpoint_id if ss.attachment[0].subnet_id == aws_subnet.subnet_firewall_a.id], 0)
  #   gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_rt_1a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}
