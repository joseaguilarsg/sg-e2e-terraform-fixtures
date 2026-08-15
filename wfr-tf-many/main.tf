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
  type    = string
  default = "eu-central-1"
}

variable "resource_count" {
  description = "How many resources to plan. Enough to paginate the resources table."
  type        = number
  default     = 40
}

provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

# FIXTURE: many resources with long addresses - pagination and truncation.
#
# ⚠️ NOT cloud resources, and that is deliberate. Two attempts to use aws_security_group failed
# for reasons that had nothing to do with what this fixture tests (measured 2026-08-15):
#   - "invalid value for name (cannot begin with sg-)" - AWS reserves that prefix for group IDs;
#   - "VPCIdNotSpecified: No default VPC for this user" - the account has no default VPC.
# So its 40 resources had ONLY EVER existed in the plan, and every case needing a populated state
# skipped for want of a subject it could not have had.
#
# random_pet needs no provider credentials, no VPC and no quota, so this fixture now applies in
# any organisation - which is also what the catalogue needs to be portable.
resource "random_pet" "many" {
  count = var.resource_count

  prefix    = format("e2e-fixture-with-a-deliberately-long-name-%03d", count.index)
  length    = 4
  separator = "-"
}

output "resource_names" {
  value = random_pet.many[*].id
}
