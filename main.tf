provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "own"
  region                  = "eu-west-1"
}

variable "region" {
  description = "The region that the resources will be instantiated in"
  default     = "eu-west-1"
}


# A more robust solution to avoid conflicts is to store the terraform state file
# on S3. To do that, we first a create an S3 bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket    = "terraform-state-mrfksiv"
  region    = var.region

  # Enable versioning so we can see the full version history of the state files
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  # Enable server side encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# S3 on its own does not solve the biggest problem which is two different people
# running terraform apply at the (almost) the same time, thus before the state file
# has reached its final state. This may result in inconsistencies.
# To enable 'locking' we will use the DynamoDB AWS service
resource "aws_dynamodb_table" "terraform_state_locks" {
  name          = "terraform-state-locks"
  hash_key      = "LockID"
  billing_mode  = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# At this point we have everything we need to store the terraform state file on S3
# however, it is still stored locally. We need to tell Terraform to change its backend
# to S3 rather than 'local':

terraform {
  backend "s3" {
    bucket                  = "terraform-state-mrfksiv"
    key                     = "global/s3/terraform.tfstate" // the file path within S3 that the tfstate will be saved in
    region                  = "eu-west-1"
    profile                 = "own"

    dynamodb_table          = "terraform-state-locks"
    encrypt                 = true
    skip_region_validation  = true
  }
}


