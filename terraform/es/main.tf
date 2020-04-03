terraform {
  backend "s3" {
    bucket = "state.terraform.prd.sirona.com"
    key    = "es/terraform.tfstate"
    region = "us-east-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "state.terraform.prd.sirona.com"
    key    = "vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

variable "aws_region" {}


variable "availability_zones" {
  description = "A list of availability zones in which to create subnets"
  type        = list(string)
}

provider "aws" {
  region = var.aws_region

  version = "~> 2.0"
}

resource "aws_elasticsearch_domain" "prd" {
  domain_name           = "prd"
  elasticsearch_version = "7.4"

  cluster_config {
    instance_type  = "r5.large.elasticsearch"
    instance_count = 2
    zone_awareness_config {
      availability_zone_count = 2
    }

    zone_awareness_enabled = true
  }


  ebs_options {
    ebs_enabled = true
    volume_size = 25
  }

  vpc_options {
    security_group_ids = [data.terraform_remote_state.vpc.outputs.default_security_group_id]
    subnet_ids         = slice(data.terraform_remote_state.vpc.outputs.private_subnets, 0, 2)
  }

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  tags = {
    Domain = "prd"
  }
}

resource "aws_elasticsearch_domain_policy" "kibana" {
  domain_name = aws_elasticsearch_domain.prd.domain_name

  access_policies = <<POLICIES
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
              "es:ESHttp*"
            ],
            "Principal": {
              "AWS": "*"
            },
            "Effect": "Allow",
            "Resource": "${aws_elasticsearch_domain.prd.arn}/_plugin/kibana/*"
        },
        {
            "Action": [
              "es:ESHttpGet",
              "es:ESHttpPost"
            ],
            "Principal": {
              "AWS": "*"
            },
            "Effect": "Allow",
            "Resource": "${aws_elasticsearch_domain.prd.arn}/*"
        }
    ]
}
POLICIES
}