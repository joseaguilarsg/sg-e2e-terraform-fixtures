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

provider "aws" {
  region = var.region
}

# FIXTURE: fails during plan, before any facts are written.
#
# The failure is a reference to a variable that is never declared. Terraform rejects it while
# evaluating the configuration, so the run dies before it produces a plan - no resource list,
# no cost estimate, no policy evaluation.
#
# ⚠️ The route matters, not just the outcome. The seeded fixture this replaces failed through
# poisoned *inputs*, which errors at plan too but takes a different path. "No facts" is the
# actual assertion of the cases that use this, so the failure has to happen before anything is
# written rather than merely end in an error.
resource "aws_s3_bucket" "broken" {
  bucket = var.this_variable_is_never_declared
}
