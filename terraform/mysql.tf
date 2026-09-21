# Managed MySQL fuer module_service (DECISION-021), analog zu database.tf.
resource "digitalocean_database_cluster" "mysql" {
  name       = "${var.cluster_name}-mysql"
  engine     = "mysql"
  version    = var.mysql_version
  size       = var.mysql_db_size
  region     = var.region
  node_count = 1
}

resource "digitalocean_database_db" "module_service" {
  cluster_id = digitalocean_database_cluster.mysql.id
  name       = var.mysql_db_name
}

resource "digitalocean_database_user" "module_service" {
  cluster_id = digitalocean_database_cluster.mysql.id
  name       = "module_service_app"
}

resource "digitalocean_database_firewall" "mysql" {
  cluster_id = digitalocean_database_cluster.mysql.id

  rule {
    type  = "k8s"
    value = digitalocean_kubernetes_cluster.this.id
  }
}
