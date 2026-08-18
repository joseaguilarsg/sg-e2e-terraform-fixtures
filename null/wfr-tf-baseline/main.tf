# Null twin of wfr-tf-baseline: the SAME mixed plan - create, update, destroy, replace and
# untouched at once - with no cloud behind it. terraform_data carries the update-in-place
# (its `input` is a plain attribute) and the replace (`triggers_replace`); random_id stays the
# untouched resource. Outputs mirror the AWS twin's names - the tests read names, not clouds.
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

variable "name_prefix" {
  type    = string
  default = "sg-e2e"
}

variable "stage" {
  description = "seed plants the pre-state, mixed is the fixture."
  type        = string
  default     = "mixed"

  validation {
    condition     = contains(["seed", "mixed"], var.stage)
    error_message = "stage must be either \"seed\" or \"mixed\"."
  }
}

locals {
  bucket_keys   = var.stage == "seed" ? ["alpha", "beta", "gamma"] : ["alpha", "beta"]
  revision      = var.stage == "seed" ? "v1" : "v2"
  replace_token = var.stage == "seed" ? "a" : "b"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "terraform_data" "fixture" {
  for_each = toset(local.bucket_keys)

  input = {
    name     = "${var.name_prefix}-${each.key}-${random_id.suffix.hex}"
    revision = local.revision
  }
}

resource "terraform_data" "replaced" {
  triggers_replace = [local.replace_token]

  input = "${var.name_prefix}-replaced-${local.replace_token}-${random_id.suffix.hex}"
}

resource "terraform_data" "added" {
  count = var.stage == "mixed" ? 1 : 0

  input = "${var.name_prefix}-added-${random_id.suffix.hex}"
}

output "bucket_names" {
  value = [for fixture in terraform_data.fixture : fixture.input.name]
}

output "bucket_count" {
  value = length(terraform_data.fixture)
}
