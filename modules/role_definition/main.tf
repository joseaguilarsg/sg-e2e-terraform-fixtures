resource "azurerm_role_definition" "this" {
  name              = var.name
  scope             = var.scope
  description       = var.description
  assignable_scopes = var.assignable_scopes

  dynamic "permissions" {
    for_each = var.permissions
    content {
      actions          = permissions.value.actions
      not_actions      = permissions.value.not_actions
      data_actions     = permissions.value.data_actions
      not_data_actions = permissions.value.not_data_actions
    }
  }
}
