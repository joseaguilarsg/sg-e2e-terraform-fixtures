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

# ⚠️ This is what makes the fixture produce a MIXED plan, and it is the whole point of the
# variable existing. Terraform can only update or delete something that is already in state, so
# a fixture that has only ever created resources can never render a `~`, a `-` or a `-/+`.
#
#   stage = "seed"    plants the previous state: three buckets and a replaceable one
#   stage = "mixed"   the fixture proper - applied ON TOP of the seed, its plan carries
#                     create, update, destroy, replace and untouched at the same time
#
# Seed first, apply once, then switch to mixed and apply again. The mixed RUN is the fixture;
# the state it leaves behind is incidental.
variable "stage" {
  description = "Which side of the fixture to render: seed plants the pre-state, mixed is the fixture."
  type        = string
  default     = "mixed"

  validation {
    condition     = contains(["seed", "mixed"], var.stage)
    error_message = "stage must be either \"seed\" or \"mixed\"."
  }
}

provider "aws" {
  region = var.region
}

locals {
  # gamma exists in the seed and is gone from the mixed stage -> a DESTROY.
  bucket_keys = var.stage == "seed" ? ["alpha", "beta", "gamma"] : ["alpha", "beta"]

  # A tag that differs between stages -> an UPDATE IN PLACE on every surviving bucket, without
  # touching anything that would force a replacement.
  revision = var.stage == "seed" ? "v1" : "v2"

  # Part of a bucket name, and a bucket name cannot be changed in place -> a REPLACE, which the
  # cases require to render as ONE row carrying both signs, never as a separate create + delete.
  replace_token = var.stage == "seed" ? "a" : "b"
}

# Untouched on purpose, and it earns its place three times over: it keeps the bucket names unique
# across all of AWS, it is the resource left UNCHANGED in the mixed plan (the cases assert those
# are still listed and marked), and a `random_*` address must leave the Service column blank while
# the `aws_*` ones read "AWS" - both sides of that assertion inside one run.
resource "random_id" "suffix" {
  byte_length = 4
}

# for_each rather than count, and several rather than one: a resource must be named by its own
# address, never by its position in a set. A singleton cannot exercise that at all.
resource "aws_s3_bucket" "fixture" {
  for_each = toset(local.bucket_keys)

  bucket = "${var.name_prefix}-${each.key}-${random_id.suffix.hex}"

  # Without this a destroy fails the moment anything lands in the bucket, and the fixture is
  # left dirty for every run after it.
  force_destroy = true

  tags = {
    Name      = each.key
    ManagedBy = "platform-qa"
    Fixture   = "wfr-tf-baseline"
    Revision  = local.revision
  }
}

# The replacement. Its name carries `replace_token`, and an S3 bucket name is force-new, so the
# stage change destroys and recreates this one resource.
resource "aws_s3_bucket" "replaced" {
  bucket = "${var.name_prefix}-replaced-${local.replace_token}-${random_id.suffix.hex}"

  force_destroy = true

  tags = {
    Name      = "replaced"
    ManagedBy = "platform-qa"
    Fixture   = "wfr-tf-baseline"
    Revision  = local.revision
  }
}

# Absent from the seed, present in the mixed stage -> a CREATE that sits alongside the update,
# the destroy and the replace in the same plan.
resource "aws_s3_bucket" "added" {
  count = var.stage == "mixed" ? 1 : 0

  bucket = "${var.name_prefix}-added-${random_id.suffix.hex}"

  force_destroy = true

  tags = {
    Name      = "added"
    ManagedBy = "platform-qa"
    Fixture   = "wfr-tf-baseline"
    Revision  = local.revision
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
