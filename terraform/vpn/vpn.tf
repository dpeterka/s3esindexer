terraform {
  backend "s3" {
    bucket = "state.terraform.prd.sirona.com"
    key    = "vpn/terraform.tfstate"
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

variable "client_cert_arn" {}

provider "aws" {
  region = var.aws_region

  version = "~> 2.0"
}

resource "aws_acmpca_certificate_authority" "sirona" {
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name = "sirona-homework.com"
    }
  }

  type = "ROOT"

  permanent_deletion_time_in_days = 7
}

resource "aws_acm_certificate" "cert" {
  domain_name               = "vpn.sirona-homework.com"
  certificate_authority_arn = aws_acmpca_certificate_authority.sirona.arn

  tags = {
    Environment = "prd"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ec2_client_vpn_endpoint" "prd" {
  description            = "sirona-homework-clientvpn-prd"
  server_certificate_arn = aws_acm_certificate.cert.arn
  client_cidr_block      = "172.16.0.0/16"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.client_cert_arn

  }

  connection_log_options {
    enabled = false
  }
}

resource "aws_ec2_client_vpn_network_association" "prd" {
  count                  = length(data.terraform_remote_state.vpc.outputs.nat_subnets)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.prd.id
  subnet_id              = data.terraform_remote_state.vpc.outputs.nat_subnets[count.index]
}