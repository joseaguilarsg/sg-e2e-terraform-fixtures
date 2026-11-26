variable "role_definitions" {
  type = map(object({
    name              = string
    scope             = string
    description       = optional(string)
    assignable_scopes = optional(list(string), [])
    permissions = optional(list(object({
      actions          = optional(list(string), [])
      not_actions      = optional(list(string), [])
      data_actions     = optional(list(string), [])
      not_data_actions = optional(list(string), [])
    })), [])
  }))
  default = {}
}
