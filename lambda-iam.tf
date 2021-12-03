terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = "${file("lambda-assume-policy.json")}"
}

variable "topic_arn" {
  description = "Value of the topic ARN for the SNS topic"
  type        = string
  default     = "aws_sns_topic.topic.arn"
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "A lambda policy"
  policy ="${file("lambda-policy.json")}"
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# grant SNS S3 bucket the permission to trigger Lambda function:
resource "aws_lambda_permission" "allow-sns-bucket" {
   statement_id = "AllowExecutionFromS3Bucket"
   action = "lambda:InvokeFunction"
   # changed
   function_name = "${aws_lambda_function.crowd_lambda.arn}"
   principal = "s3.amazonaws.com"
   # changed
   source_arn = "${aws_s3_bucket.sns-bucket.arn}"
}

# use "s3:ObjectCreated:*" so we can get a notification when a file is added in our sns S3 bucket:
resource "aws_s3_bucket_notification" "bucket_terraform_notification" {
   # changed
   bucket = "${aws_s3_bucket.sns-bucket.id}"
   lambda_function {
       # changed
       lambda_function_arn = "${aws_lambda_function.crowd_lambda.arn}"
       events = ["s3:ObjectCreated:*"]
   }
   # depends on us granting s3 bucket permission to trigger lambda (previous resource block)
   # changed
   depends_on = [ aws_lambda_permission.allow-sns-bucket ]
}

# source bucket for sns
resource "aws_s3_bucket" "sns-bucket" {
   bucket = "sns-src-bucket"
   force_destroy = true
   acl    = "public-read"
   tags = {
     Name = "Source Bucket For SNS"
   }
}

# source bucket for amplify front end
resource "aws_s3_bucket" "amplify-bucket" {
   bucket = "amplify-src-bucket"
   force_destroy = true
   acl    = "public-read"
   tags = {
     Name = "Source Bucket For Amplify"
   }
}

resource "aws_s3_bucket_policy" "sns-bucket" {
  bucket = aws_s3_bucket.sns-bucket.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2008-10-17",
    "Id": "Policy1380877762691",
    "Statement": [
        {
            "Sid": "Stmt1380877761162",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::sns-src-bucket/*"
        }
    ]
})
}


resource "aws_s3_bucket_policy" "amplify-bucket" {
  bucket = aws_s3_bucket.amplify-bucket.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2008-10-17",
    "Id": "Policy1380877762691",
    "Statement": [
        {
            "Sid": "Stmt1380877761162",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::amplify-src-bucket/*"
        }
    ]
})
}

resource "aws_lambda_function_event_invoke_config" "crowd_lambda" {
  function_name = aws_lambda_function.crowd_lambda.function_name
  destination_config {
    on_success {
      destination = aws_sns_topic.crowd_lambda.arn
    }
  }
}

#SNS topic with email subscription
resource "aws_sns_topic" "crowd_lambda" {
  name = "crowd_lambda"
}

resource "aws_sns_topic_subscription" "crowd_email_subscription" {
  count     = length(local.emails)
  topic_arn = aws_sns_topic.crowd_lambda.arn
  protocol  = "email"
  endpoint  = local.emails[count.index]
}

# Main ec2 server running script
#resource "aws_instance" "ec2_server" {
#  ami           = "ami-04ad2567c9e3d7893"
#  instance_type = "t2.micro"
#  key_name = "swen-iam-us-east-1"
#  tags = {
#    Terraform = "true"
#    Name = "Python Script Server"
#  }
#}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region used for server deployment"
}

variable "repo_url" {
  type        = string
  default     = "https://github.com/swen-cloud-team-8/amplifyapp7"
  description = "URL used for repo"
}

variable "repo_branch" {
  type        = string
  default     = "master"
  description = "Branch used for repo"
}

variable "access_token" {
  type        = string
#   default     = "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"
  description = "Access token used to access the repo"
}

resource "aws_amplify_app" "amplify-terr-test" {
  name       = "amp-terr-test"
  repository = var.repo_url
  # GitHub personal access token
  access_token = var.access_token

  # The default rewrites and redirects added by the Amplify Console.
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }

  #Auto Branch Creation
  enable_auto_branch_creation = true

  # The default patterns added by the Amplify Console.
  auto_branch_creation_patterns = [
    "*",
    "*/**",
  ]

  enable_branch_auto_build = true
}

resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.amplify-terr-test.id
  branch_name = var.repo_branch
  provisioner "local-exec" {
    command = "aws amplify start-job --app-id ${aws_amplify_app.amplify-terr-test.id} --branch-name master --job-type RELEASE"
  }

}

#Reference: https://levelup.gitconnected.com/aws-lambda-asynchronous-invocations-with-destinations-5a2d47082fe9
#Reference: https://technotrampoline.com/articles/how-to-add-email-subscribers-to-an-aws-sns-topic-with-terraform/
#Reference: https://hands-on.cloud/terraform-deploy-lambda-to-copy-files-between-s3-buckets/
#Reference: https://levelup.gitconnected.com/deploy-lambda-function-with-terraform-966d069978bb.
#Reference: https://medium.com/@awsyadav/execute-lambda-functions-on-s3-event-triggers-c0193929f17e
#Reference: https://awspolicygen.s3.amazonaws.com/policygen.html
