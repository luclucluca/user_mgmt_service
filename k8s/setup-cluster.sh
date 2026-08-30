#!/usr/bin/env bash
#
# Baut die komplette Infrastruktur von Grund auf neu auf:
# DOKS-Cluster -> ingress-nginx -> cert-manager -> ArgoCD -> Host ermitteln ->
# ArgoCD Application registrieren (GitOps aus helm/user-mgmt in diesem Repo).
#
# Idempotent: existiert der Cluster bereits, wird er weiterverwendet.
#
# Voraussetzung: doctl authentifiziert (doctl auth init), kubectl und helm installiert.
#
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-k8s-vscmodul}"
REGION="${REGION:-fra1}"
NODE_SIZE="${NODE_SIZE:-s-2vcpu-4gb}"
NODE_COUNT="${NODE_COUNT:-1}"
NAMESPACE="user-mgmt"
STAGING_NAMESPACE="user-mgmt-staging"
# Muessen mit den Hosts in 06-ingress.yaml und dem Build-Arg in deploy.yml
# uebereinstimmen.
HOSTS=("lucavonsaal.com" "www.lucavonsaal.com")
# ArgoCD-Dashboard, siehe k8s/argocd-values.yaml. Rein informativ fuer den
# DNS-Check unten, an keiner anderen Stelle im Skript verdrahtet.
ARGOCD_HOST="argocd.lucavonsaal.com"
STAGING_HOST="staging.lucavonsaal.com"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="${REPO_ROOT}/k8s"
ENV_FILE="${REPO_ROOT}/.env"
WORKFLOW="${REPO_ROOT}/.github/workflows/deploy.yml"

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
# Muss vor dem Apply der Manifests laufen: 07-tls-issuer.yaml enthaelt einen
# ClusterIssuer, dessen CRD erst von cert-manager mitgebracht wird. Ohne diesen
# Schritt bricht "kubectl apply -f k8s/" mit "no matches for kind" ab.
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
# Voraussetzung fuer den Horizontal Pod Autoscaler (Aufgabe 6): er liefert die
# Metrics API, aus der der HPA CPU- und Speicherauslastung liest. Ohne ihn
# steht der HPA dauerhaft auf "<unknown>" und skaliert nie.
#
# Aeltere DOKS-Images brachten metrics-server mit, das aktuelle (v1.36, Cilium)
# nicht mehr - deshalb hier explizit.
#
# --kubelet-insecure-tls: die Kubelets stellen Zertifikate auf ihre interne IP
# aus, die metrics-server nicht gegen die Cluster-CA verifizieren kann.
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
info "ArgoCD installieren"
# ---------------------------------------------------------------------------
# Eigener, von der Applikation getrennter Namespace (Aufgabe 3). Die Werte in
# argocd-values.yaml schalten TLS-Terminierung an den Ingress durch (server.insecure)
# und aktivieren dessen Ingress auf argocd.lucavonsaal.com.
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
# Der Host ist seit der TLS-Umstellung fest in 06-ingress.yaml und deploy.yml
# verdrahtet, es wird nichts mehr per sed nachgezogen. Die A-Records liegen bei
# einem externen Registrar (nicht in der DigitalOcean-DNS-Zone) und muessen
# nach einem Cluster-Neuaufbau manuell auf die neue IP gezeigt werden.
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
# Cluster-weite Ressource, unabhaengig vom GitOps-Ablauf unten. Braucht die
# ACME-Adresse aus .env, siehe apply-tls-issuer.sh. Ein fehlender Eintrag darf
# den Rest des Aufbaus nicht abbrechen, deshalb das if/else statt "||".
if "${K8S_DIR}/apply-tls-issuer.sh"; then
  ok "ClusterIssuer angewendet"
else
  warn "ClusterIssuer uebersprungen — es gibt kein TLS."
  warn "ACME_EMAIL in .env nachtragen, dann: ./k8s/apply-tls-issuer.sh"
fi

# ---------------------------------------------------------------------------
info "Applikationen via ArgoCD ausrollen (Prod + Staging)"
# ---------------------------------------------------------------------------
# Die statischen Manifests k8s/0[0-6]-*.yaml (Aufgabe 1) werden bewusst NICHT
# mehr angewendet: ArgoCD deployt dieselbe Anwendung ueber den Helm Chart
# unter helm/user-mgmt in zwei getrennte Namespaces (Prod/Staging).
#
# Das Secret wird bewusst nicht vom Chart erzeugt (secrets.create=false, siehe
# helm/user-mgmt/values.yaml). Es entsteht deshalb hier, einmalig pro
# Namespace, aus der lokalen .env.
[ -f "${ENV_FILE}" ] || { echo "FEHLER: ${ENV_FILE} nicht gefunden"; exit 1; }
env_value() { grep -E "^${1}=" "${ENV_FILE}" | cut -d= -f2-; }

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

deploy_env "${NAMESPACE}" user-mgmt-secret user-mgmt-postgres argocd-application-prod.yaml
ok "Prod (${NAMESPACE}) bereit"

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

cat <<EOF

────────────────────────────────────────────────────────────────────
Infrastruktur steht. LoadBalancer-IP: ${LB_IP}
Prod-Hosts: ${HOSTS[*]}
Staging-Host: ${STAGING_HOST} (Namespace ${STAGING_NAMESPACE})

ArgoCD Dashboard: https://${ARGOCD_HOST}
  Login: admin / ${ARGOCD_ADMIN_PW:-<kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d>}

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
