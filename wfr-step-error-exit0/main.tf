terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# FIXTURE: prints an error banner and exits 0.
#
# The run SUCCEEDS. That is the whole point: the log looks like a failure and the outcome is not
# one, so any surface that decides "failed" by scanning the log for error-looking text gets it
# wrong here. The exit code is the truth; the banner is noise.
#
# The plan already names an existing instance of this (`simple-ec2-g8qe`, step `preprepre`), but
# that lives in a personal workflow group - the churn this repo exists to replace.
resource "null_resource" "misleading" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "--- ERROR ---"
      echo "fixture wfr-step-error-exit0 | the banner above is deliberate and means nothing"
      echo "Error: this line also looks like a failure and also is not one"
      exit 0
    EOT
  }

  triggers = {
    always = timestamp()
  }
}
