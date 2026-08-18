# Null twin of wfr-apply-fail: the plan succeeds and the APPLY fails - a create-time provisioner
# exits 1 where the AWS twin collides on a taken bucket. Same shape: plan facts survive, the
# errors surface carries the apply failure alone.
variable "taken_bucket_name" {
  description = "Mirrors the AWS twin's input; here it only names what the apply claims to attempt."
  type        = string
  default     = "sg-e2e-taken-do-not-delete"
}

resource "terraform_data" "clash" {
  input = var.taken_bucket_name

  provisioner "local-exec" {
    command = "echo '[SG_ERROR] apply failing on purpose: ${var.taken_bucket_name} is taken'; exit 1"
  }
}

output "attempted_bucket" {
  value = var.taken_bucket_name
}
