# A configuration whose APPLY succeeds and whose DESTROY always fails, on purpose.
#
# TC-WFRUNS-UI-072 asks what a failed destroy looks like: the plan facts of the apply have to
# survive while the destroy reports its own error. Producing that by breaking credentials or
# deleting the resource by hand is non-deterministic — it depends on state nobody controls.
#
# `prevent_destroy` is the deterministic version: Terraform refuses at PLAN time of the destroy,
# with "Instance cannot be destroyed", every single time and without touching the cloud.
#
# ⚠️ That also means this fixture's resource CANNOT be removed while the lifecycle rule is in the
# config. Cleaning it up takes deleting these lines first, then destroying.

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_pet" "undestroyable" {
  length = 2

  lifecycle {
    prevent_destroy = true
  }
}

output "name" {
  value = random_pet.undestroyable.id
}
