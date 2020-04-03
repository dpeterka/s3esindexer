# AWS services

In this exercise, I am chosing to use many hosted AWS services. 
Configuring OS level changes is outside of the scope of this exercise and I am opting to use provided services to hit
a minimum viable product.

## Elasticsearch Service
Access control to Elasticsearch Service is complex and let's me have different actions allowed for Kibana users and the Lambda functions responsible for indexing.

## Lambda
S3 object events can notify Lambda functions directly so I am leveraging that to perform the ES index fuctions.