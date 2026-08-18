# Null twin of wfr-in-flight: the same deliberate hold, nothing created in any cloud.
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

variable "hold_seconds" {
  description = "How long the run stalls. Long enough to arrive and act, not longer."
  type        = string
  default     = "180s"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# `triggers = timestamp()` is what makes the hold happen on EVERY apply, not only the first.
resource "time_sleep" "hold" {
  create_duration = var.hold_seconds

  triggers = {
    run = timestamp()
  }
}

resource "terraform_data" "slow" {
  input      = "sg-e2e-inflight-${random_id.suffix.hex}"
  depends_on = [time_sleep.hold]
}

output "bucket_name" {
  value = terraform_data.slow.input
}
