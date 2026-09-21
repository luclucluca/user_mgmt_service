#!/usr/bin/env bash
# Baut die Infrastruktur (Cluster, Ingress, cert-manager, ArgoCD) idempotent auf.
# Voraussetzung: doctl authentifiziert, kubectl und helm installiert.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-k8s-vscmodul}"
REGION="${REGION:-fra1}"
NODE_SIZE="${NODE_SIZE:-s-2vcpu-4gb}"
# 2 Nodes minimum: ein PDB waere auf einem einzigen Node wirkungslos.
# MAX_NODES gibt dem Cluster-Autoscaler Luft, wenn der HPA ueber die Node-Kapazitaet hinaus skaliert.
NODE_COUNT="${NODE_COUNT:-2}"
MIN_NODES="${MIN_NODES:-2}"
MAX_NODES="${MAX_NODES:-3}"
NAMESPACE="user-mgmt"
STAGING_NAMESPACE="user-mgmt-staging"
# Muessen mit ingress.hosts in helm/user-mgmt/values-prod.yaml uebereinstimmen.
HOSTS=("lucavonsaal.com" "www.lucavonsaal.com")
# ArgoCD-Dashboard, siehe k8s/argocd-values.yaml. Rein informativ fuer den
# DNS-Check unten, an keiner anderen Stelle im Skript verdrahtet.
ARGOCD_HOST="argocd.lucavonsaal.com"
STAGING_HOST="staging.lucavonsaal.com"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="${REPO_ROOT}/k8s"
ENV_FILE="${REPO_ROOT}/.env"
WORKFLOW="${REPO_ROOT}/.github/workflows/deploy.yml"
TF_DIR="${REPO_ROOT}/terraform"

info()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m!   %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓   %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
info "Voraussetzungen pruefen"
# ---------------------------------------------------------------------------
for bin in doctl kubectl helm dig; do
  command -v "$bin" >/dev/null || { echo "FEHLER: $bin nicht gefunden"; exit 1; }
done
doctl account get >/dev/null || { echo "FEHLER: doctl nicht authentifiziert"; exit 1; }
ok "doctl, kubectl, helm, dig vorhanden"

# ---------------------------------------------------------------------------
info "Cluster '${CLUSTER_NAME}' bereitstellen"
# ---------------------------------------------------------------------------
if doctl kubernetes cluster get "${CLUSTER_NAME}" >/dev/null 2>&1; then
  ok "Cluster existiert bereits – wird weiterverwendet"
  doctl kubernetes cluster kubeconfig save "${CLUSTER_NAME}"
else
  warn "Ab jetzt entstehen Kosten (Node-Pool + spaeter ein LoadBalancer)."
  # --wait: doctl kehrt erst zurueck, wenn der Cluster 'running' ist (ca. 5 Min).
  # kubeconfig wird dabei automatisch gespeichert und aktiviert.
  doctl kubernetes cluster create "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --version latest \
    --node-pool "name=pool-app;size=${NODE_SIZE};count=${NODE_COUNT}" \
    --wait
  ok "Cluster erstellt"
fi

# Eigener Schritt statt im --node-pool-String, damit es auch bei bereits bestehendem Cluster greift.
POOL_ID=$(doctl kubernetes cluster node-pool list "${CLUSTER_NAME}" \
            --format ID --no-header | head -1)
if [ -n "${POOL_ID}" ]; then
  doctl kubernetes cluster node-pool update "${CLUSTER_NAME}" "${POOL_ID}" \
    --auto-scale --min-nodes "${MIN_NODES}" --max-nodes "${MAX_NODES}" >/dev/null
  ok "Node-Pool auf Autoscaling ${MIN_NODES}-${MAX_NODES} gesetzt"
else
  warn "Node-Pool nicht gefunden - Autoscaling nicht gesetzt"
fi

kubectl config use-context "do-${REGION}-${CLUSTER_NAME}" >/dev/null 2>&1 || true
kubectl get nodes

# ---------------------------------------------------------------------------
info "Ingress Controller installieren"
# ---------------------------------------------------------------------------
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update ingress-nginx >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.publishService.enabled=true \
  --wait --timeout 10m >/dev/null
ok "ingress-nginx installiert"

# ---------------------------------------------------------------------------
info "cert-manager installieren"
# ---------------------------------------------------------------------------
# Muss vor dem ClusterIssuer-Apply laufen: dessen CRD kommt erst mit cert-manager.
helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
helm repo update jetstack >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 10m >/dev/null
ok "cert-manager installiert"

# ---------------------------------------------------------------------------
info "metrics-server installieren"
# ---------------------------------------------------------------------------
# Voraussetzung fuer den HPA (Metrics API); ohne ihn bleibt die Auslastung "<unknown>".
# --kubelet-insecure-tls, da Kubelet-Zertifikate nicht gegen die Cluster-CA verifizierbar sind.
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
helm repo update metrics-server >/dev/null
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args={--kubelet-insecure-tls}' \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=100Mi \
  --wait --timeout 5m >/dev/null
ok "metrics-server installiert (kubectl top nodes zum Pruefen)"

# ---------------------------------------------------------------------------
info "kube-prometheus-stack installieren (Observability)"
# ---------------------------------------------------------------------------
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f "${K8S_DIR}/monitoring-values.yaml" \
  --wait --timeout 10m >/dev/null
kubectl apply -f "${K8S_DIR}/grafana-dashboard-user-mgmt-backend.yaml" >/dev/null
ok "kube-prometheus-stack installiert"

# ---------------------------------------------------------------------------
info "Kyverno installieren (Policy as Code, Aufgabe 5)"
# ---------------------------------------------------------------------------
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update kyverno >/dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --namespace policy --create-namespace \
  -f "${K8S_DIR}/kyverno-values.yaml" \
  --wait --timeout 5m >/dev/null
kubectl apply -f "${K8S_DIR}/kyverno-policies.yaml" >/dev/null
ok "Kyverno installiert, ClusterPolicies angewendet"

# ---------------------------------------------------------------------------
info "ArgoCD installieren"
# ---------------------------------------------------------------------------
# Eigener Namespace, getrennt von der Applikation; TLS wird am Ingress terminiert (server.insecure).
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f "${K8S_DIR}/argocd-values.yaml" \
  --wait --timeout 10m >/dev/null
ok "ArgoCD installiert"

# ---------------------------------------------------------------------------
info "Auf LoadBalancer-IP warten (DigitalOcean provisioniert, ca. 2-5 Min)"
# ---------------------------------------------------------------------------
LB_IP=""
for _ in $(seq 1 60); do
  LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "${LB_IP}" ] && break
  sleep 10
done
[ -n "${LB_IP}" ] || { echo "FEHLER: keine LoadBalancer-IP erhalten"; exit 1; }

ok "LoadBalancer-IP: ${LB_IP}"

# ---------------------------------------------------------------------------
info "DNS pruefen"
# ---------------------------------------------------------------------------
# A-Records liegen extern (nicht bei DigitalOcean) und muessen nach Neuaufbau manuell nachgezogen werden.
# Ohne korrektes DNS scheitert die HTTP-01-Challenge von Let's Encrypt.
DNS_OK=1
for host in "${HOSTS[@]}"; do
  resolved=$(dig +short A "${host}" | tail -1)
  if [ "${resolved}" = "${LB_IP}" ]; then
    ok "${host} -> ${resolved}"
  else
    warn "${host} -> ${resolved:-<keine Antwort>} (erwartet ${LB_IP})"
    DNS_OK=0
  fi
done
for h in "${ARGOCD_HOST}" "${STAGING_HOST}"; do
  resolved=$(dig +short A "${h}" | tail -1)
  if [ "${resolved}" = "${LB_IP}" ]; then
    ok "${h} -> ${resolved}"
  else
    warn "${h} -> ${resolved:-<keine Antwort>} (erwartet ${LB_IP})"
    DNS_OK=0
  fi
done
if [ "${DNS_OK}" -eq 0 ]; then
  warn "A-Records auf ${LB_IP} zeigen lassen, sonst bleibt das Zertifikat aus."
  warn "Die Anwendung laeuft trotzdem an, nur ohne gueltiges TLS."
fi

# ---------------------------------------------------------------------------
info "ClusterIssuer anwenden"
# ---------------------------------------------------------------------------
# Fehlender ACME_EMAIL-Eintrag darf den restlichen Aufbau nicht abbrechen, deshalb if/else statt "||".
if "${K8S_DIR}/apply-tls-issuer.sh"; then
  ok "ClusterIssuer angewendet"
else
  warn "ClusterIssuer uebersprungen — es gibt kein TLS."
  warn "ACME_EMAIL in .env nachtragen, dann: ./k8s/apply-tls-issuer.sh"
fi

# ---------------------------------------------------------------------------
info "Terraform anwenden (Managed PostgreSQL fuer Prod, Aufgabe 4)"
# ---------------------------------------------------------------------------
# Cluster-ID und -Version aendern sich bei jedem Neuaufbau. Statt den Import Block
# stillschweigend veralten zu lassen (State zeigt sonst auf einen geloeschten Cluster,
# siehe DECISION zu Aufgabe 4), wird er hier immer frisch aus dem laufenden Cluster gezogen.
[ -f "${TF_DIR}/terraform.tfvars" ] || { echo "FEHLER: ${TF_DIR}/terraform.tfvars nicht gefunden (siehe terraform.tfvars.example)"; exit 1; }
CLUSTER_ID=$(doctl kubernetes cluster get "${CLUSTER_NAME}" --format ID --no-header)
CLUSTER_VERSION=$(doctl kubernetes cluster get "${CLUSTER_NAME}" --format Version --no-header)
sed -E -i.bak "s/id = \"[0-9a-f-]{36}\"/id = \"${CLUSTER_ID}\"/" "${TF_DIR}/import.tf"
rm -f "${TF_DIR}/import.tf.bak"
terraform -chdir="${TF_DIR}" state rm digitalocean_kubernetes_cluster.this >/dev/null 2>&1 || true
terraform -chdir="${TF_DIR}" init -input=false >/dev/null
terraform -chdir="${TF_DIR}" apply -auto-approve -input=false -var="kubernetes_version=${CLUSTER_VERSION}" >/dev/null
ok "Terraform angewendet - Cluster importiert, Managed PostgreSQL bereit"

DB_HOST=$(terraform -chdir="${TF_DIR}" output -raw postgres_host)
DB_PORT=$(terraform -chdir="${TF_DIR}" output -raw postgres_port)
DB_NAME=$(terraform -chdir="${TF_DIR}" output -raw postgres_db_name)
DB_USER=$(terraform -chdir="${TF_DIR}" output -raw postgres_app_user)
DB_PASSWORD=$(terraform -chdir="${TF_DIR}" output -raw postgres_app_password)
PROD_DATASOURCE_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require"

# ---------------------------------------------------------------------------
info "Schema-Rechte auf Managed PostgreSQL vergeben"
# ---------------------------------------------------------------------------
# PostgreSQL 15+ entzieht neu erzeugten Nicht-Owner-Rollen (hier: der App-User)
# standardmaessig CREATE/USAGE auf das Schema "public" - ohne diesen Schritt
# scheitert Hibernates DDL beim ersten Start mit "permission denied for schema
# public" und jeder DB-Zugriff wirft eine unbehandelte Exception (siehe DECISION
# zu Aufgabe 6). Admin-Zugangsdaten werden nur ephemer verwendet, nie als
# Kubernetes Secret angelegt.
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
ADMIN_USER=$(terraform -chdir="${TF_DIR}" output -raw postgres_admin_user)
ADMIN_PASSWORD=$(terraform -chdir="${TF_DIR}" output -raw postgres_admin_password)
GRANT_SQL_FILE=$(mktemp)
cat > "${GRANT_SQL_FILE}" <<SQL
GRANT ALL PRIVILEGES ON SCHEMA public TO "${DB_USER}";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "${DB_USER}";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "${DB_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "${DB_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${DB_USER}";
SQL
kubectl create configmap postgres-grant-sql -n "${NAMESPACE}" --from-file=grant.sql="${GRANT_SQL_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
rm -f "${GRANT_SQL_FILE}"
kubectl delete pod postgres-grant-perms -n "${NAMESPACE}" --ignore-not-found --wait >/dev/null 2>&1
kubectl run postgres-grant-perms -n "${NAMESPACE}" --image=postgres:16-alpine --restart=Never \
  --overrides="{
    \"spec\": {
      \"containers\": [{
        \"name\": \"postgres-grant-perms\",
        \"image\": \"postgres:16-alpine\",
        \"command\": [\"sh\", \"-c\", \"PGSSLMODE=require psql -h ${DB_HOST} -p ${DB_PORT} -U ${ADMIN_USER} -d ${DB_NAME} -f /sql/grant.sql\"],
        \"env\": [{\"name\": \"PGPASSWORD\", \"value\": \"${ADMIN_PASSWORD}\"}],
        \"volumeMounts\": [{\"name\": \"sql\", \"mountPath\": \"/sql\"}],
        \"resources\": {\"requests\": {\"cpu\": \"20m\", \"memory\": \"32Mi\"}, \"limits\": {\"cpu\": \"50m\", \"memory\": \"64Mi\"}}
      }],
      \"volumes\": [{\"name\": \"sql\", \"configMap\": {\"name\": \"postgres-grant-sql\"}}]
    }
  }" >/dev/null
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/postgres-grant-perms -n "${NAMESPACE}" --timeout=60s
kubectl logs postgres-grant-perms -n "${NAMESPACE}" 2>&1
kubectl delete pod postgres-grant-perms -n "${NAMESPACE}" --ignore-not-found >/dev/null
kubectl delete configmap postgres-grant-sql -n "${NAMESPACE}" --ignore-not-found >/dev/null
ok "Schema-Rechte vergeben"

MYSQL_HOST=$(terraform -chdir="${TF_DIR}" output -raw mysql_host)
MYSQL_PORT=$(terraform -chdir="${TF_DIR}" output -raw mysql_port)
MYSQL_DB=$(terraform -chdir="${TF_DIR}" output -raw mysql_db_name)
MYSQL_USER=$(terraform -chdir="${TF_DIR}" output -raw mysql_app_user)
MYSQL_PASSWORD=$(terraform -chdir="${TF_DIR}" output -raw mysql_app_password)
MODULE_SERVICE_DATABASE_URL="mysql+pymysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}?charset=utf8mb4"

# ---------------------------------------------------------------------------
info "Applikationen via ArgoCD ausrollen (Prod + Staging)"
# ---------------------------------------------------------------------------
# Secret entsteht hier statt im Chart (secrets.create=false), damit es nicht in Git landet.
[ -f "${ENV_FILE}" ] || { echo "FEHLER: ${ENV_FILE} nicht gefunden"; exit 1; }
env_value() { grep -E "^${1}=" "${ENV_FILE}" | cut -d= -f2-; }

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
# Prod bezieht die Datenbank ueber die Managed PostgreSQL (Terraform) statt ueber den
# Postgres-StatefulSet im Cluster - deshalb SPRING_DATASOURCE_URL zusaetzlich im Secret,
# es ueberschreibt den ConfigMap-Wert (envFrom: ConfigMap vor Secret, siehe backend.yaml).
kubectl create secret generic user-mgmt-secret -n "${NAMESPACE}" \
  --from-literal=SPRING_DATASOURCE_URL="${PROD_DATASOURCE_URL}" \
  --from-literal=SPRING_DATASOURCE_USERNAME="${DB_USER}" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD}" \
  --from-literal=JWT_SECRET="$(env_value JWT_SECRET)" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f "${K8S_DIR}/argocd-application-prod.yaml"
for _ in $(seq 1 60); do
  kubectl get deployment/user-mgmt-backend -n "${NAMESPACE}" >/dev/null 2>&1 && break
  sleep 5
done
kubectl rollout status deployment/user-mgmt-backend -n "${NAMESPACE}" --timeout=300s
ok "Prod (${NAMESPACE}) bereit (Managed PostgreSQL)"

# ---------------------------------------------------------------------------
info "module_service ausrollen (Aufgabe 6, Managed MySQL)"
# ---------------------------------------------------------------------------
# Laeuft im selben Namespace wie user-mgmt-backend, siehe helm/module-service/values.yaml.
kubectl create secret generic module-service-secret -n "${NAMESPACE}" \
  --from-literal=DATABASE_URL="${MODULE_SERVICE_DATABASE_URL}" \
  --from-literal=MYSQL_HOST="${MYSQL_HOST}" \
  --from-literal=MYSQL_PORT="${MYSQL_PORT}" \
  --from-literal=MYSQL_USER="${MYSQL_USER}" \
  --from-literal=MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
  --from-literal=MYSQL_DB="${MYSQL_DB}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f "${K8S_DIR}/argocd-application-module-service.yaml"
for _ in $(seq 1 60); do
  kubectl get deployment/module-service -n "${NAMESPACE}" >/dev/null 2>&1 && break
  sleep 5
done
kubectl rollout status deployment/module-service -n "${NAMESPACE}" --timeout=300s
ok "module_service bereit"

deploy_env() {
  local ns="$1" secret_name="$2" statefulset="$3" app_file="$4"

  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl create secret generic "${secret_name}" -n "${ns}" \
    --from-literal=SPRING_DATASOURCE_USERNAME="$(env_value SPRING_DATASOURCE_USERNAME)" \
    --from-literal=SPRING_DATASOURCE_PASSWORD="$(env_value SPRING_DATASOURCE_PASSWORD)" \
    --from-literal=JWT_SECRET="$(env_value JWT_SECRET)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  kubectl apply -f "${K8S_DIR}/${app_file}"

  for _ in $(seq 1 60); do
    kubectl get "pod/${statefulset}-0" -n "${ns}" >/dev/null 2>&1 && break
    sleep 5
  done
  kubectl wait --for=condition=Ready "pod/${statefulset}-0" -n "${ns}" --timeout=300s
}

deploy_env "${STAGING_NAMESPACE}" user-mgmt-staging-secret user-mgmt-staging-postgres argocd-application-staging.yaml
ok "Staging (${STAGING_NAMESPACE}) bereit"

# ---------------------------------------------------------------------------
info "Status"
# ---------------------------------------------------------------------------
kubectl get pods,svc,pvc,ingress,resourcequota,networkpolicy -n "${NAMESPACE}"
kubectl get pods,svc,pvc,ingress,resourcequota,networkpolicy -n "${STAGING_NAMESPACE}"
kubectl get application -n argocd

ARGOCD_ADMIN_PW=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)

GRAFANA_ADMIN_PW=$(kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || true)

cat <<EOF

────────────────────────────────────────────────────────────────────
Infrastruktur steht. LoadBalancer-IP: ${LB_IP}
Prod-Hosts: ${HOSTS[*]}
Staging-Host: ${STAGING_HOST} (Namespace ${STAGING_NAMESPACE})

ArgoCD Dashboard: https://${ARGOCD_HOST}
  Login: admin / ${ARGOCD_ADMIN_PW:-<kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d>}

Grafana (kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80):
  Login: admin / ${GRAFANA_ADMIN_PW:-<kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d>}

Backend und Frontend stehen auf ErrImagePull, solange die Images
fehlen. Naechste Schritte:

  1. Falls die DNS-Pruefung oben gewarnt hat: A-Records der Hosts auf
     ${LB_IP} zeigen lassen und warten, bis sie aufloesen. Ohne DNS
     stellt Let's Encrypt kein Zertifikat aus.

  2. Falls oben gewarnt wurde, dass ACME_EMAIL fehlt: in .env
     nachtragen und den Issuer anwenden:
       ./k8s/apply-tls-issuer.sh

  3. GHCR-Packages auf 'public' stellen (GitHub -> Packages ->
     Package settings -> Change visibility), sonst wird zusaetzlich
     ein imagePullSecret benoetigt.

  4. Die Pipeline aktualisiert nach einem Build automatisch den Image-Tag in
     helm/user-mgmt/values.yaml (Promotion-Commit) - ArgoCD zieht das
     innerhalb weniger Minuten nach. Manuell geht's schneller:
       kubectl rollout restart deployment/user-mgmt-backend deployment/user-mgmt-frontend -n ${NAMESPACE}
       kubectl rollout status  deployment/user-mgmt-backend deployment/user-mgmt-frontend -n ${NAMESPACE}

  5. Zertifikat pruefen (READY muss True werden, dauert 1-2 Min):
       kubectl get certificate -n ${NAMESPACE} -w

  6. Testen:
       curl -s -o /dev/null -w "%{http_code}\\n" https://${HOSTS[0]}/

  7. Deployment aendern laeuft ab jetzt nur noch ueber Commits auf main
     (helm/user-mgmt/values.yaml), nicht mehr per kubectl/helm direkt.

Cluster wieder abbauen (stoppt die Kosten):
       ./k8s/teardown-cluster.sh
────────────────────────────────────────────────────────────────────
EOF
