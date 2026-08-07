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

variable "label" {
  description = "Present so the workflow has an input to render. It changes nothing."
  type        = string
  default     = "no-op"
}

provider "aws" {
  region = var.region
}

# FIXTURE: a plan that finds nothing to do, every time.
#
# There are no resources at all, so the plan is empty on the first run and on every run after
# it. That determinism is the point: the alternative - applying the baseline and planning it
# again - only reads as a no-op while nothing drifts, and the moment anything changes outside
# Terraform the fixture quietly stops being one.
#
# A no-op is its own outcome, distinct from a plan that failed and from one that had changes:
# it has to end without an apply while still counting as a successful run.
#
# ⚠️ No outputs, deliberately. An output is itself a planned change — measured: with one declared,
# the first plan reports "Changes to Outputs" and the fixture is only a no-op from the second run
# onwards. Declaring nothing at all is what makes it empty on every run, including the first.

locals {
  unused = var.label
}
