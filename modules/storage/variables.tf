variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "apps_subnet_id" {
  description = "Sous-reseau autorise a joindre le compte de stockage."
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "name_suffix" {
  description = "Suffixe si le nom du compte est deja pris (le nom doit etre unique au monde)."
  type        = string
  default     = ""
}
