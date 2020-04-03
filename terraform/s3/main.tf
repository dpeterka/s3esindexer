terraform {
  backend "s3" {
    bucket = "state.terraform.prd.sirona.com"
    key    = "s3/terraform.tfstate"
    region = "us-east-2"
  }
}

variable "aws_region" {}

provider "aws" {
  region = var.aws_region

  version = "~> 2.0"
}

resource "aws_s3_bucket" "tracked_bucket" {
  bucket = "data.tracked.sirona-homework.com"
  acl    = "private"

  tags = {
    Name        = "Tracked data sirona-homework"
    Environment = "prd"
  }
}

resource "aws_iam_role" "user_upload" {
  name = "dataUploader"

  assume_role_policy = <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:PutObject"
         ],
         "Resource": "${aws_s3_bucket.tracked_bucket.arn}/*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:ListBucket"
         ],
         "Resource": "${aws_s3_bucket.tracked_bucket.arn}"
      }
   ]
}
EOF

  tags = {
    Environment = "prd"
    Description = "allows uploads to s3://${aws_s3_bucket.tracked_bucket.id}"
  }
}