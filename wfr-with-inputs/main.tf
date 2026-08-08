terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# FIXTURE: more inputs than the collapsed section shows, so the "+N more" affordance appears.
#
# The section names the first two and counts the rest, so anything above two exercises it. Six
# is enough to make a wrong count obvious - with three, "+1" and "+2" are easy to confuse when
# reading a screenshot.
#
# The types differ on purpose: the cases assert values keep their Terraform shape - strings
# quoted, numbers and booleans bare, structures as raw objects. A fixture of six strings would
# let a page that quotes everything pass.

variable "bucket_name" {
  description = "A plain string."
  type        = string
  default     = "sg-e2e-inputs"
}

variable "region" {
  description = "A second string, so the collapsed preview has two to name."
  type        = string
  default     = "eu-central-1"
}

variable "retention_days" {
  description = "A number - must render bare, not quoted."
  type        = number
  default     = 30
}

variable "versioning_enabled" {
  description = "A boolean - must render bare, not quoted."
  type        = bool
  default     = true
}

variable "allowed_cidrs" {
  description = "A list - must render as a structure."
  type        = list(string)
  default     = ["10.0.0.0/16", "192.168.0.0/24"]
}

variable "tags" {
  description = "A map - the longest value, for truncation and for the copy affordance."
  type        = map(string)
  default = {
    ManagedBy   = "platform-qa"
    Fixture     = "wfr-with-inputs"
    Environment = "e2e-testing-with-a-deliberately-long-value-to-exercise-truncation"
  }
}

resource "null_resource" "inputs" {
  triggers = {
    bucket_name        = var.bucket_name
    region             = var.region
    retention_days     = var.retention_days
    versioning_enabled = var.versioning_enabled
    allowed_cidrs      = join(",", var.allowed_cidrs)
    tags               = jsonencode(var.tags)
  }
}

# ⚠️ EXPERIMENT, not yet a fixture: Terraform's own way of marking an input secret. Nobody has
# measured what the run detail does with it — whether the value comes back masked, comes back in
# the clear, or never leaves the plan at all. Until that is measured, no case should assert on it:
# `test_run_inputs_section.py` already refuses to, and it is right to
# ("asserting it against a run without one would pass vacuously").
variable "api_token" {
  description = "Marked sensitive so the platform has something to mask, if it masks anything."
  type        = string
  sensitive   = true
  default     = "sg-e2e-not-a-real-secret"
}
