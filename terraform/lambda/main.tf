terraform {
  backend "s3" {
    bucket = "state.terraform.prd.sirona.com"
    key    = "lambda/terraform.tfstate"
    region = "us-east-2"
  }
}

data "terraform_remote_state" "es" {
  backend = "s3"
  config = {
    bucket = "state.terraform.prd.sirona.com"
    key    = "es/terraform.tfstate"
    region = "us-east-2"
  }
}

data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket = "state.terraform.prd.sirona.com"
    key    = "s3/terraform.tfstate"
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

provider "aws" {
  region = var.aws_region

  version = "~> 2.0"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_policy" "lambda_vpc_access" {
  name        = "lambda_vpc_access"
  path        = "/"
  description = "IAM policy for VPC access from a lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeNetworkInterfaces"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_vpc_access.arn
}

resource "aws_iam_policy" "lambda_s3_access" {
  name        = "lambda_s3_access"
  path        = "/"
  description = "IAM policy for s3 access from a lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "${data.terraform_remote_state.s3.outputs.tracked_bucket_arn}/*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

resource "aws_iam_policy" "lambda_es_access" {
  name        = "lambda_es_access"
  path        = "/"
  description = "IAM policy for es access from a lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "es:ESHttp*"
            ],
            "Resource": "${data.terraform_remote_state.es.outputs.es_arn}/*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_es_access" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_es_access.arn
}

resource "aws_cloudwatch_log_group" "s3esdelete" {
  name              = "/aws/lambda/s3esdelete"
  retention_in_days = 14
}

resource "aws_lambda_permission" "delete_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3esdelete.arn
  principal     = "s3.amazonaws.com"
  source_arn    = data.terraform_remote_state.s3.outputs.tracked_bucket_arn
}

resource "aws_lambda_function" "s3esdelete" {
  filename      = "s3esdelete.zip"
  function_name = "s3esdelete"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("s3esdelete.zip")

  runtime = "python3.7"

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.nat_subnets
    security_group_ids = [data.terraform_remote_state.vpc.outputs.default_security_group_id]
  }

  environment {
    variables = {
      ELASTICSEARCH_ENDPOINT = data.terraform_remote_state.es.outputs.es_endpoint
    }
  }
}



resource "aws_lambda_permission" "index_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3esindex.arn
  principal     = "s3.amazonaws.com"
  source_arn    = data.terraform_remote_state.s3.outputs.tracked_bucket_arn
}

resource "aws_cloudwatch_log_group" "s3esindex" {
  name              = "/aws/lambda/s3esindex"
  retention_in_days = 14
}


resource "aws_lambda_function" "s3esindex" {
  filename      = "s3esindex.zip"
  function_name = "s3esindex"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("s3esindex.zip")

  runtime = "python3.7"

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.nat_subnets
    security_group_ids = [data.terraform_remote_state.vpc.outputs.default_security_group_id]
  }

  environment {
    variables = {
      ELASTICSEARCH_ENDPOINT = data.terraform_remote_state.es.outputs.es_endpoint
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = data.terraform_remote_state.s3.outputs.tracked_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3esdelete.arn
    events              = ["s3:ObjectRemoved:*"]
  }
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3esindex.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.delete_allow_bucket, aws_lambda_permission.index_allow_bucket]
}