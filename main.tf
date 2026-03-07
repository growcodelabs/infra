module "environment" {
  source = "./modules/environment"

  name     = terraform.workspace
  ip_range = "10.0.0.0/24"
  region   = "nyc3"

  databases = {
    shared = {}
  }

  default_node_pool = {
    node_count = 1
  }
}
