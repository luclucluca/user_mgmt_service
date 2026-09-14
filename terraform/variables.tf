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
  description = "DOKS-Version. Explizit gepinnt statt 'latest' (wie in setup-cluster.sh bei der Erstellung), damit Terraform keine ungewollten Upgrades vorschlaegt."
  type        = string
  default     = "1.36.3-do.4"
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
