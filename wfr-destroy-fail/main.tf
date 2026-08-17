# A configuration whose APPLY succeeds and whose DESTROY plans cleanly but FAILS while executing.
#
# TC-WFRUNS-UI-072: a failed destroy has the same SHAPE as a failed apply — the plan facts written
# before the failure survive it, and the errors tab carries the destroy error alone. So the
# destroy has to reach its EXECUTION and fail there. `prevent_destroy` (the earlier version) is the
# wrong shape: it refuses at the destroy's PLAN time, so no plan facts ever exist to survive.
#
# A destroy-time local-exec that exits non-zero is deterministic and touches no cloud: the apply
# creates the null_resource, the destroy plans it for deletion (writing the plan/cost/compliance
# facts), then the provisioner runs and fails, leaving the destroy ERRORED at its execution.

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "fails_on_destroy" {
  provisioner "local-exec" {
    when    = destroy
    command = "echo '[SG_ERROR] destroy step failing on purpose'; exit 1"
  }
}

output "name" {
  value = null_resource.fails_on_destroy.id
}
