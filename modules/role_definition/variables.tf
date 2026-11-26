variable "name" {
  type = string
}

variable "scope" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "assignable_scopes" {
  type    = list(string)
  default = []
}

variable "permissions" {
  type = list(object({
    actions          = optional(list(string), [])
    not_actions      = optional(list(string), [])
    data_actions     = optional(list(string), [])
    not_data_actions = optional(list(string), [])
  }))
  default = []
}
