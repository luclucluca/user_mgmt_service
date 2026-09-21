# Aus generated.tf bereinigt (DECISION-018): GPU-Bloecke und node_count entfernt
# (Konflikte bzw. wird vom Autoscaler verwaltet), computed Nullwerte weggelassen.
resource "digitalocean_kubernetes_cluster" "this" {
  name    = var.cluster_name
  region  = var.region
  version = var.kubernetes_version

  auto_upgrade  = false
  ha            = true
  surge_upgrade = true

  coredns_autoscaler {
    enabled = true
  }

  maintenance_policy {
    day        = "any"
    start_time = "00:00"
  }

  node_pool {
    name       = "pool-app"
    size       = var.node_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
  }
}
