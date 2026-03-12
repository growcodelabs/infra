locals {
  region   = "nyc3"
  registry = "growcodelabs"
}

import {
  id = local.registry
  to = digitalocean_container_registry.registry
}

resource "digitalocean_container_registry" "registry" {
  name   = local.registry
  region = local.region

  subscription_tier_slug = "starter"
}

module "environment" {
  source = "./modules/environment"

  name     = terraform.workspace
  ip_range = "10.0.0.0/24"
  region   = local.region

  databases = {
    shared = {}
  }

  default_node_pool = {
    node_count = 2
  }
}
