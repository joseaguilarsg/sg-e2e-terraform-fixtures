terraform {
  required_providers {
    # FIXTURE: dies during init, before any step produces logs.
    #
    # The provider does not exist in the registry, so `terraform init` fails while resolving
    # it. Nothing after init ever starts: no plan, no logs from a step, no facts.
    #
    # ⚠️ That is the distinction the cases rest on. A step that fails still produced a step and
    # its output; an init failure means the run died before the first step existed, and the
    # surfaces that read "which step failed" have nothing to read at all.
    nonexistent = {
      source  = "stackguardian/this-provider-does-not-exist"
      version = "99.99.99"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

resource "nonexistent_thing" "never_created" {
  name = "unreachable"
}
