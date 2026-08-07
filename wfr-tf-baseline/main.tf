terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

variable "region" {
  description = "AWS region the fixture buckets are created in."
  type        = string
  default     = "eu-central-1"
}

variable "name_prefix" {
  description = "Prefix for every bucket. Keep it short - bucket names cap at 63 characters."
  type        = string
  default     = "sg-e2e"
}

provider "aws" {
  region = var.region
}

# The suffix is what makes the fixture re-appliable: S3 bucket names are unique across all of
# AWS, so a fixed name collides with someone else's bucket and the apply fails in a way that
# reads as a product bug. It doubles as the utility resource the breakdown cases need - a
# `random_*` address renders its Service column as a dash while the `aws_*` ones read "AWS",
# so one run carries both sides of that assertion.
resource "random_id" "suffix" {
  byte_length = 4
}

# for_each rather than count, and three of them rather than one: a resource must be named by
# its own address, never by its position in a set. A singleton cannot exercise that at all.
resource "aws_s3_bucket" "fixture" {
  for_each = toset(["alpha", "beta", "gamma"])

  bucket = "${var.name_prefix}-${each.key}-${random_id.suffix.hex}"

  # Without this a destroy fails the moment anything lands in the bucket, and the fixture is
  # left dirty for every run after it.
  force_destroy = true

  tags = {
    Name      = each.key
    ManagedBy = "platform-qa"
    Fixture   = "wfr-tf-baseline"
  }
}

output "bucket_names" {
  description = "Every bucket this fixture created, in address order."
  value       = [for bucket in aws_s3_bucket.fixture : bucket.bucket]
}

output "bucket_count" {
  description = "How many buckets exist - a scalar output next to the list one."
  value       = length(aws_s3_bucket.fixture)
}
