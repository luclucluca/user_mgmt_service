# Fuer setup-cluster.sh, das daraus das Kubernetes Secret anlegt. private_host
# statt host: DOKS und DB liegen im selben VPC, kein oeffentlicher Endpunkt noetig.
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

# Nur fuer den einmaligen Schema-GRANT in setup-cluster.sh, nie als Secret persistiert.
output "postgres_admin_user" {
  value = digitalocean_database_cluster.postgres.user
}

output "postgres_admin_password" {
  value     = digitalocean_database_cluster.postgres.password
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
