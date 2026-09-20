variable "do_token" {
  description = "DigitalOcean API-Token. Nie im Repository - lokal per terraform.tfvars (gitignored) oder TF_VAR_do_token."
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name des bestehenden DOKS-Clusters, siehe CLUSTER_NAME in k8s/setup-cluster.sh."
  type        = string
  default     = "k8s-vscmodul"
}

variable "region" {
  description = "DigitalOcean-Region, siehe REGION in k8s/setup-cluster.sh."
  type        = string
  default     = "fra1"
}

variable "kubernetes_version" {
  description = "DOKS-Version. Explizit gepinnt statt 'latest' (wie in setup-cluster.sh bei der Erstellung), damit Terraform keine ungewollten Upgrades vorschlaegt. Aenderungen an diesem Wert ersetzen den Cluster (ForceNew) - vor jedem Import/Apply mit 'doctl kubernetes cluster get' gegenpruefen."
  type        = string
  default     = "1.36.3-do.5"
}

variable "node_size" {
  description = "Node-Groesse des Pools 'pool-app', siehe NODE_SIZE in k8s/setup-cluster.sh."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "min_nodes" {
  description = "Untergrenze des Cluster-Autoscalers, siehe MIN_NODES in k8s/setup-cluster.sh."
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Obergrenze des Cluster-Autoscalers, siehe MAX_NODES in k8s/setup-cluster.sh."
  type        = number
  default     = 3
}

variable "postgres_version" {
  description = "Engine-Version der Managed PostgreSQL Database (Aufgabe 4)."
  type        = string
  default     = "16"
}

variable "postgres_db_size" {
  description = "Groesse der Managed PostgreSQL Database. Kleinste Stufe fuer eine Modulaufgabe."
  type        = string
  default     = "db-s-1vcpu-1gb"
}

variable "postgres_db_name" {
  description = "Name der logischen Datenbank innerhalb des Managed-DB-Clusters."
  type        = string
  default     = "user_mgmt"
}
