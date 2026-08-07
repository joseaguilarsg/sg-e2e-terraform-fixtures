terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# FIXTURE: no variables at all.
#
# The counterpart to wfr-with-inputs. A run triggered with nothing to declare should render the
# Inputs section as empty rather than omit it, or omit it rather than render it empty - the case
# asserts which, and it cannot be checked against a configuration that has inputs.
#
# ⚠️ Nothing declared, deliberately. Adding even a defaulted variable makes this identical to
# wfr-with-inputs with fewer values, and the distinction the case rests on disappears.
resource "null_resource" "no_inputs" {
  triggers = {
    fixture = "wfr-no-inputs"
  }
}
