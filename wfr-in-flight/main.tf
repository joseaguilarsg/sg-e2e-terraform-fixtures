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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "hold_seconds" {
  description = "How long the run stalls. Long enough for the whole in-flight block to read one run."
  type        = string
  default     = "600s"
}

provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

# FIXTURE: a run slow enough to be watched while it is still going.
#
# Everything about an in-flight run - the live badge, the streaming logs, the cancel control and
# every state cancel can be triggered from - needs a run that is still running when the test
# looks at it. Without a deliberate hold, a fixture that finishes in 40s is a race: the test
# either wins it or reports a flake, and neither outcome says anything about the product.
#
# The hold sits BEFORE the resource so the stall happens during plan/apply rather than after
# everything already exists.
#
# 🔴 `triggers` is what makes this fixture work more than once, and it was measured the hard way.
# `time_sleep` sleeps when it is CREATED. Without a trigger it lands in state on the first apply
# and every apply after that plans it as a no-op, so the hold silently stops happening: the apply
# phase collapsed from 109s to 17s on a repeat run. `timestamp()` differs on every plan, so the
# resource is replaced each time and the hold always runs.
#
# ⚠️ The consequence is that this fixture's plan always carries a replacement. That is deliberate
# here; do not copy the pattern into a fixture whose plan shape is what a case asserts on.
resource "time_sleep" "hold" {
  create_duration = var.hold_seconds

  triggers = {
    run = timestamp()
  }
}

resource "aws_s3_bucket" "slow" {
  bucket        = "sg-e2e-inflight-${random_id.suffix.hex}"
  force_destroy = true

  depends_on = [time_sleep.hold]

  tags = {
    ManagedBy = "platform-qa"
    Fixture   = "wfr-in-flight"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.slow.bucket
}
