# Verbindungsdaten fuer k8s/setup-cluster.sh, das daraus das Kubernetes Secret anlegt.
# private_host statt host: DOKS und die Managed Database liegen im selben VPC,
# damit bleibt die Verbindung intern und braucht keinen oeffentlichen Endpunkt.
output "postgres_host" {
  value = digitalocean_database_cluster.postgres.private_host
}

output "postgres_port" {
  value = digitalocean_database_cluster.postgres.port
}

output "postgres_db_name" {
  value = digitalocean_database_db.user_mgmt.name
}

output "postgres_app_user" {
  value = digitalocean_database_user.app.name
}

output "postgres_app_password" {
  value     = digitalocean_database_user.app.password
  sensitive = true
}

output "mysql_host" {
  value = digitalocean_database_cluster.mysql.private_host
}

output "mysql_port" {
  value = digitalocean_database_cluster.mysql.port
}

output "mysql_db_name" {
  value = digitalocean_database_db.module_service.name
}

output "mysql_app_user" {
  value = digitalocean_database_user.module_service.name
}

output "mysql_app_password" {
  value     = digitalocean_database_user.module_service.password
  sensitive = true
}
