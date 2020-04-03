output "public_subnets" {
    value = aws_subnet.public[*].id
}

output "nat_subnets" {
    value = aws_subnet.nat[*].id
}

output "private_subnets" {
    value = aws_subnet.private[*].id
}

output "default_security_group_id" {
    value = aws_vpc.prd.default_security_group_id
}

output "vpc_id" {
    value = aws_vpc.prd.id
}