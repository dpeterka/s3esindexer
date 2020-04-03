output "es_endpoint" {
    value = aws_elasticsearch_domain.prd.endpoint
}

output "es_arn" {
    value = aws_elasticsearch_domain.prd.arn
}

output "es_domain_name" {
    value = aws_elasticsearch_domain.prd.domain_name
}