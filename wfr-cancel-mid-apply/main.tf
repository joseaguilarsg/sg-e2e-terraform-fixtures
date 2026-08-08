# An apply that has ALREADY CREATED something by the time the cancel window opens.
#
# TC-WFRUNS-UI asks what a run cancelled mid-apply looks like when at least one resource exists.
# `wfr-in-flight` cannot answer it: there the hold sits BEFORE its bucket on purpose, so the whole
# cancel window falls while nothing has been created yet and the run is cancelled with an empty
# state. No amount of timing fixes that — it is the order of the graph, not the length of the wait.
#
# So this one inverts it:
#
#     1 · `first` is created immediately
#     2 · the hold runs, and it is `depends_on` the bucket, so it cannot start earlier
#     3 · `second` would be created after, and never is when the run is cancelled during the hold
#
# ⇒ Cancelling any time inside the hold leaves exactly one resource created and one pending, every
# time, without having to hit a window of seconds.

terraform {
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 5.0" }
    time = { source = "hashicorp/time", version = "~> 0.9" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "hold_seconds" {
  description = "How wide the cancel window is. Three minutes is long enough to open the UI and act."
  type        = string
  default     = "180s"
}

provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Created FIRST — this is the resource the case needs to already exist.
resource "aws_s3_bucket" "first" {
  bucket        = "sg-e2e-cancel-first-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name    = "first"
    Fixture = "wfr-cancel-mid-apply"
  }
}

# ⚠️ `time_sleep` only sleeps when it is CREATED. The trigger forces a replacement on every apply,
# otherwise the second run plans it as a no-op and the hold silently stops happening.
resource "time_sleep" "hold" {
  create_duration = var.hold_seconds
  depends_on      = [aws_s3_bucket.first]

  triggers = {
    run = timestamp()
  }
}

# Never reached when the run is cancelled inside the hold — which is the point.
resource "aws_s3_bucket" "second" {
  bucket        = "sg-e2e-cancel-second-${random_id.suffix.hex}"
  force_destroy = true
  depends_on    = [time_sleep.hold]

  tags = {
    Name    = "second"
    Fixture = "wfr-cancel-mid-apply"
  }
}
