#!/usr/bin/env bash
# Baut den Cluster vollstaendig ab und stoppt damit die laufenden Kosten.
# LoadBalancer/Volumes werden dynamisch angelegt und muessen vor dem Cluster entfernt werden, sonst bleiben sie verwaist zurueck.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-k8s-vscmodul}"
# Beide Umgebungen: sonst bleibt z.B. das Staging-PVC als kostenpflichtiges Volume zurueck.
NAMESPACES=("user-mgmt" "user-mgmt-staging")
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

info() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓   %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!   %s\033[0m\n' "$*"; }

# Managed PostgreSQL (Aufgabe 4) haengt nicht am Cluster - ohne diesen Schritt laeuft
# die Kostenberechnung weiter, obwohl der Cluster laengst weg ist.
if [ -f "${TF_DIR}/terraform.tfvars" ] && terraform -chdir="${TF_DIR}" state list 2>/dev/null | grep -q digitalocean_database; then
  info "Managed PostgreSQL abbauen (Terraform)"
  terraform -chdir="${TF_DIR}" destroy -auto-approve -input=false \
    -target=digitalocean_database_firewall.postgres \
    -target=digitalocean_database_user.app \
    -target=digitalocean_database_db.user_mgmt \
    -target=digitalocean_database_cluster.postgres
  ok "Managed PostgreSQL geloescht"
else
  warn "Kein Terraform-State fuer die Managed PostgreSQL gefunden - manuell pruefen: doctl databases list"
fi

if ! doctl kubernetes cluster get "${CLUSTER_NAME}" >/dev/null 2>&1; then
  warn "Cluster '${CLUSTER_NAME}' existiert nicht – springe zur Restpruefung"
else
  info "Applikation entfernen (gibt das PersistentVolume frei)"
  for ns in "${NAMESPACES[@]}"; do
    kubectl delete namespace "${ns}" --ignore-not-found --timeout=180s || true
  done

  info "Ingress Controller entfernen (gibt den LoadBalancer frei)"
  helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
  kubectl delete namespace ingress-nginx --ignore-not-found --timeout=180s || true

  # DigitalOcean braucht einen Moment, bis der LoadBalancer tatsaechlich weg ist.
  sleep 20

  info "Cluster loeschen"
  doctl kubernetes cluster delete "${CLUSTER_NAME}" --force --dangerous
  ok "Cluster geloescht"
fi

info "Restpruefung auf verwaiste, kostenpflichtige Ressourcen"
echo "--- Cluster ---";       doctl kubernetes cluster list
echo "--- Load Balancer ---"; doctl compute load-balancer list --format ID,Name,IP,Status
echo "--- Volumes ---";       doctl compute volume list --format ID,Name,Size,Region
echo "--- Databases ---";     doctl databases list --format ID,Name,Status

cat <<'EOF'

Sind die drei Listen leer, fallen keine Cluster-Kosten mehr an.
Steht dort noch etwas, manuell entfernen:
    doctl compute load-balancer delete <id>
    doctl compute volume delete <id>

Hinweis: Droplets werden hier nicht angefasst. Ein ausgeschaltetes Droplet
wird von DigitalOcean weiterhin voll verrechnet – nur 'destroy' beendet die
Kosten:
    doctl compute droplet list
    doctl compute droplet delete <id>
EOF
