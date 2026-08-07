terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

variable "line_count" {
  description = "How many lines to emit. Large enough that the log is served through a pointer rather than inline."
  type        = number
  default     = 50000
}

# FIXTURE: a log too large to be served inline.
#
# Below some size the platform returns the log in the response body; above it, a pointer to
# fetch separately. The cases assert the viewer behaves the same either way - nothing truncated,
# the tail present.
#
# ⚠️ The threshold is a backend property and is NOT measured. 50k lines is deliberately far past
# any plausible cutoff rather than tuned to it: a fixture that sits near the boundary would flip
# between the two paths as the log format changes, and a test that passes for the wrong reason
# is worse than one that fails.
resource "null_resource" "noisy" {
  provisioner "local-exec" {
    command = "seq 1 ${var.line_count} | awk '{printf \"line %07d | fixture wfr-logs-large | padding to make each line long enough that the total size is unambiguous\\n\", $1}'"
  }

  triggers = {
    always = timestamp()
  }
}
