data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "digitalocean_vpc" "this" {
  region   = var.region
  ip_range = var.ip_range
  name     = "network-${var.name}"
}

data "digitalocean_kubernetes_versions" "versions" {
  version_prefix = "1.34"
}

resource "digitalocean_kubernetes_cluster" "this" {
  region = var.region
  ha     = var.k8s_ha
  name   = "${var.name}-k8s"

  vpc_uuid = digitalocean_vpc.this.id

  version = data.digitalocean_kubernetes_versions.versions.latest_version

  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }

  node_pool {
    name       = var.default_node_pool.name
    size       = var.default_node_pool.size
    node_count = var.default_node_pool.node_count
  }
}

resource "digitalocean_database_cluster" "this" {
  for_each = var.databases

  name = "${var.name}-${each.key}-${each.value.engine}"

  engine  = each.value.engine
  version = each.value.version
  size    = each.value.size

  node_count = each.value.node_count

  private_network_uuid = digitalocean_vpc.this.id
  region               = digitalocean_vpc.this.region
}

resource "digitalocean_database_firewall" "this" {
  for_each = var.databases

  cluster_id = digitalocean_database_cluster.this[each.key].id

  rule {
    type  = "k8s"
    value = digitalocean_kubernetes_cluster.this.id
  }

  rule {
    type  = "ip_addr"
    value = local.my_ip
  }
}
