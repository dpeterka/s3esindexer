terraform {
  backend "s3" {
    bucket = "state.terraform.prd.sirona.com"
    key    = "vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

variable "aws_region" {}

variable "base_cidr_block" {
  description = "A /16 CIDR range definition, such as 10.0.0.0/16, that the VPC will use"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "A list of availability zones in which to create subnets"
  type        = list(string)
}

provider "aws" {
  region = var.aws_region

  version = "~> 2.0"
}

resource "aws_vpc" "prd" {
  cidr_block           = var.base_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "prd"
    Description = "Production"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.prd.id
  cidr_block        = cidrsubnet(aws_vpc.prd.cidr_block, 8, count.index + 32)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = format("public-%s", var.availability_zones[count.index])
    Environment = "prd"
    Type        = "Public"
    Zone        = var.availability_zones[count.index]
  }
}

resource "aws_subnet" "nat" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.prd.id
  cidr_block        = cidrsubnet(aws_vpc.prd.cidr_block, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = format("nat-%s", var.availability_zones[count.index])
    Environment = "prd"
    Type        = "NAT"
    Zone        = var.availability_zones[count.index]
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.prd.id
  cidr_block        = cidrsubnet(aws_vpc.prd.cidr_block, 8, count.index + 16)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = format("private-%s", var.availability_zones[count.index])
    Environment = "prd"
    Type        = "Private"
    Zone        = var.availability_zones[count.index]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prd.id

  tags = {
    Environment = "prd"
  }
}

resource "aws_eip" "nat" {
  count = length(var.availability_zones)
  vpc   = true
  tags = {
    Environment = "prd"
    Zone        = var.availability_zones[count.index]
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = length(aws_subnet.public[*].id)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "public" {
  count = length(aws_nat_gateway.ngw[*].id)

  vpc_id = aws_vpc.prd.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}


resource "aws_route_table" "nat" {
  count = length(aws_nat_gateway.ngw[*].id)

  vpc_id = aws_vpc.prd.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw[count.index].id
  }
}

resource "aws_route_table_association" "nat" {
  count          = length(aws_subnet.nat[*].id)
  subnet_id      = aws_subnet.nat[count.index].id
  route_table_id = aws_route_table.nat[count.index].id
}
