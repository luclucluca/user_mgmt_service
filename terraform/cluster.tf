# Aus generated.tf uebernommen und bereinigt (siehe DECISION zu Aufgabe 3):
# - GPU/DRA-Addon-Bloecke entfernt: alle "enabled = false", fuer diesen Cluster ohne GPU-Nodes
#   irrelevant, und amd_gpu_device_plugin/amd_gpu_dra_driver etc. stehen laut Provider im
#   Konflikt zueinander, wenn beide explizit gesetzt sind (Terraform-Plan schlug sonst fehl).
# - node_count aus dem node_pool entfernt: bei auto_scale=true ist das Feld vom Cluster-
#   Autoscaler verwaltet (aktueller Wert war 0) - ein expliziter Wert wuerde Terraform bei
#   jedem Apply versuchen lassen, die Node-Anzahl auf diesen fixen Wert zurueckzusetzen.
# - Rein computed/optionale Nullwerte (vpc_uuid, cluster_subnet, service_subnet,
#   worker_subnet_uuid, kubeconfig_expire_seconds, registry_integration,
#   destroy_all_associated_resources, tags, labels) entfernt - von DigitalOcean verwaltet,
#   nicht Teil der gewuenschten Konfiguration.
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
