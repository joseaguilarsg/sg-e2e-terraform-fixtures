# Null twin of wfr-plan-fail: dies inside the plan on an undeclared variable, cloud untouched.
resource "terraform_data" "broken" {
  input = var.this_variable_is_never_declared
}
