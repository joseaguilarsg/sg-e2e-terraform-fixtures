# Null twin of wfr-no-op: zero resources, so every plan proposes nothing.
variable "label" {
  description = "Present so the workflow has an input to render. It changes nothing."
  type        = string
  default     = "no-op"
}

locals {
  unused = var.label
}
