variable "resource_group_id" {
  description = "Portee de l'attribution de strategie."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
