variable "name" {
  type = string
}

variable "ip_range" {
  type = string
}

variable "region" {
  type = string
}

variable "k8s_ha" {
  type    = bool
  default = false
}

variable "default_node_pool" {
  type = object({
    name       = optional(string, "apps")
    size       = optional(string, "s-2vcpu-2gb")
    node_count = optional(number, 1)
  })

  default = {
    name       = "apps"
    size       = "s-2vcpu-2gb"
    node_count = 0
  }
}

variable "databases" {
  type = map(object({
    engine     = optional(string, "pg")
    version    = optional(string, "18")
    size       = optional(string, "db-s-1vcpu-1gb")
    node_count = optional(number, 1)
  }))

  default = {}
}
