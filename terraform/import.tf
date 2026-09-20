# Uebernimmt den bereits per k8s/setup-cluster.sh erstellten Cluster in die Terraform-Verwaltung,
# statt ihn neu zu erstellen. Cluster-ID per "doctl kubernetes cluster get k8s-vscmodul" ermittelt.
import {
  to = digitalocean_kubernetes_cluster.this
  # Cluster wurde am 2026-09-20 ab- und wieder aufgebaut (neue ID, siehe DECISIONS.md).
  id = "0ffcdeea-474f-4583-a489-4a16cc2b5b56"
}
