# Uebernimmt den bereits per k8s/setup-cluster.sh erstellten Cluster in die Terraform-Verwaltung,
# statt ihn neu zu erstellen. Cluster-ID per "doctl kubernetes cluster get k8s-vscmodul" ermittelt.
import {
  to = digitalocean_kubernetes_cluster.this
  id = "f1ea4915-39ab-47d6-8026-63133582cbf0"
}
