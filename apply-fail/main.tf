terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

# The bucket this fixture deliberately collides with. It has to exist beforehand and nobody
# may delete it, or the apply starts succeeding and the fixture stops being one.
variable "taken_bucket_name" {
  description = "A bucket name that already exists. The collision is the whole point."
  type        = string
  default     = "sg-e2e-taken-do-not-delete"
}

provider "aws" {
  region = var.region
}

# FIXTURE: the plan succeeds, the apply fails.
#
# The name is fixed on purpose - no random suffix. Terraform cannot know the bucket is taken
# until it asks AWS, so the plan renders a complete, valid set of facts and only the apply
# blows up with BucketAlreadyExists.
#
# That split is exactly what the cases assert: the plan's facts survive a failed apply. A
# fixture that failed at plan instead would leave nothing to check.
resource "aws_s3_bucket" "clash" {
  bucket = var.taken_bucket_name

  tags = {
    ManagedBy = "platform-qa"
    Fixture   = "apply-fail"
  }
}

output "attempted_bucket" {
  value = var.taken_bucket_name
}
