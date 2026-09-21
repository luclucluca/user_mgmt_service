# Managed PostgreSQL fuer Prod (DECISION-019). Staging bleibt selbst betrieben.
resource "digitalocean_database_cluster" "postgres" {
  name       = "${var.cluster_name}-postgres"
  engine     = "pg"
  version    = var.postgres_version
  size       = var.postgres_db_size
  region     = var.region
  node_count = 1
}

resource "digitalocean_database_db" "user_mgmt" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = var.postgres_db_name
}

resource "digitalocean_database_user" "app" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "user_mgmt_app"
}

# Ohne diese Regel lehnt die DB jede Verbindung ab, auch aus demselben VPC.
resource "digitalocean_database_firewall" "postgres" {
  cluster_id = digitalocean_database_cluster.postgres.id

  rule {
    type  = "k8s"
    value = digitalocean_kubernetes_cluster.this.id
  }
}
