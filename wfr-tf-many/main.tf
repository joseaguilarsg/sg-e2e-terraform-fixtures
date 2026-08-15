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
# ⚠️ Security groups rather than buckets on purpose. The default S3 quota is 100 buckets per
# account and the baseline fixture already spends some; 40 more would put a shared account
# near the ceiling, and the fixture would start failing for a reason that has nothing to do
# with what it tests. Security groups have a far higher limit and cost nothing.
resource "aws_security_group" "many" {
  count = var.resource_count

  # ⚠️ NOT "sg-...": AWS reserves that prefix for security-group IDs and rejects any group named
  # with it ("invalid value for name (cannot begin with sg-)"). Measured 2026-08-15, which is why
  # these 40 resources had only ever existed in the plan - every apply of this fixture failed at
  # validation, and the cases needing a populated state skipped for want of a subject.
  name        = "${format("e2e-fixture-with-a-deliberately-long-name-%03d", count.index)}-${random_id.suffix.hex}"
  description = "Fixture resource ${count.index} - the long name is what exercises truncation"

  tags = {
    ManagedBy = "platform-qa"
    Fixture   = "wfr-tf-many"
    Index     = count.index
  }
}

output "resource_names" {
  value = aws_security_group.many[*].name
}
