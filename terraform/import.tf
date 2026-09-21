# Uebernimmt den bereits per k8s/setup-cluster.sh erstellten Cluster in die Terraform-Verwaltung,
# statt ihn neu zu erstellen. Cluster-ID per "doctl kubernetes cluster get k8s-vscmodul" ermittelt.
import {
  to = digitalocean_kubernetes_cluster.this
  # Cluster wurde zuletzt am 2026-09-21 ab- und wieder aufgebaut (neue ID, siehe DECISIONS.md).
  id = "a13e2e31-2a11-4bbf-bcdf-b05f1e72799d"
}
