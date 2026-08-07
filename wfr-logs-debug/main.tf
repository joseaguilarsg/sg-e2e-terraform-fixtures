terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# FIXTURE: a run whose log carries a debug line.
#
# The case reads this run twice - as a normal user and as support - because the two are not
# meant to see the same thing. What makes it a fixture is that the marker is deterministic and
# unique enough to assert on without matching something the runner happens to print.
#
# ⚠️ The literal below is a guess at the shape, not field-truth. Which marker the platform
# treats as debug-only lives in the runner (`sg-run-controller`), not in this repo - the same
# gap that blocks TC-225's control markers. Confirm the real token before writing the assertion,
# or the test matches a string we invented and passes for the wrong reason.
resource "null_resource" "debug_line" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "fixture wfr-logs-debug | ordinary line, visible to everyone"
      echo "[SG_DEBUG] fixture wfr-logs-debug | this line is the assertion"
      echo "fixture wfr-logs-debug | ordinary line after the debug one"
    EOT
  }

  triggers = {
    always = timestamp()
  }
}
