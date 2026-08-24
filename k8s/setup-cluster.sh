#!/usr/bin/env bash
#
# Baut die komplette Infrastruktur fuer Aufgabe 1 von Grund auf neu auf:
# DOKS-Cluster -> ingress-nginx -> Host ermitteln -> Manifests anpassen -> apply.
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
# Muessen mit den Hosts in 06-ingress.yaml und dem Build-Arg in deploy.yml
# uebereinstimmen.
HOSTS=("lucavonsaal.com" "www.lucavonsaal.com")

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="${REPO_ROOT}/k8s"
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
if [ "${DNS_OK}" -eq 0 ]; then
  warn "A-Records auf ${LB_IP} zeigen lassen, sonst bleibt das Zertifikat aus."
  warn "Die Anwendung laeuft trotzdem an, nur ohne gueltiges TLS."
fi

# ---------------------------------------------------------------------------
info "Manifests ausrollen"
# ---------------------------------------------------------------------------
# 00 bis 06 direkt. 07 wird separat behandelt, weil dort die ACME-Adresse
# eingesetzt werden muss, die absichtlich nicht im Manifest steht.
for manifest in "${K8S_DIR}"/0[0-6]-*.yaml; do
  kubectl apply -f "${manifest}"
done

ACME_EMAIL=$(grep -E '^ACME_EMAIL=' "${REPO_ROOT}/.env" 2>/dev/null | cut -d= -f2- || true)
if [ -n "${ACME_EMAIL}" ]; then
  # Ueber stdin, damit die Adresse nicht in die versionierte Datei geschrieben wird.
  sed "s|PLACEHOLDER_ACME_EMAIL|${ACME_EMAIL}|" "${K8S_DIR}/07-tls-issuer.yaml" \
    | kubectl apply -f -
  ok "ClusterIssuer mit ACME_EMAIL aus .env angewendet"
else
  warn "ACME_EMAIL fehlt in .env — ClusterIssuer uebersprungen, es gibt kein TLS."
  warn "Nachtragen und dann: sed \"s|PLACEHOLDER_ACME_EMAIL|<adresse>|\" \\"
  warn "  ${K8S_DIR}/07-tls-issuer.yaml | kubectl apply -f -"
fi

info "Auf PostgreSQL warten"
kubectl wait --for=condition=Ready pod/postgres-0 -n "${NAMESPACE}" --timeout=300s

# ---------------------------------------------------------------------------
info "Status"
# ---------------------------------------------------------------------------
kubectl get pods,svc,pvc,ingress -n "${NAMESPACE}"

cat <<EOF

────────────────────────────────────────────────────────────────────
Infrastruktur steht. LoadBalancer-IP: ${LB_IP}
Hosts: ${HOSTS[*]}

Backend und Frontend stehen auf ErrImagePull, solange die Images
fehlen. Naechste Schritte:

  1. Falls die DNS-Pruefung oben gewarnt hat: A-Records der Hosts auf
     ${LB_IP} zeigen lassen und warten, bis sie aufloesen. Ohne DNS
     stellt Let's Encrypt kein Zertifikat aus.

  2. Falls oben gewarnt wurde, dass ACME_EMAIL fehlt: in .env
     nachtragen und den Issuer anwenden (die Adresse wird bewusst
     nicht in das versionierte Manifest geschrieben):
       sed "s|PLACEHOLDER_ACME_EMAIL|<adresse>|" \\
         ${K8S_DIR}/07-tls-issuer.yaml | kubectl apply -f -

  3. GHCR-Packages auf 'public' stellen (GitHub -> Packages ->
     Package settings -> Change visibility), sonst wird zusaetzlich
     ein imagePullSecret benoetigt.

  4. Nach dem Actions-Run die Pods auf das neue 'latest' ziehen lassen:
       kubectl rollout restart deployment/backend deployment/frontend -n ${NAMESPACE}
       kubectl rollout status  deployment/backend deployment/frontend -n ${NAMESPACE}

  5. Zertifikat pruefen (READY muss True werden, dauert 1-2 Min):
       kubectl get certificate -n ${NAMESPACE} -w

  6. Testen:
       curl -s -o /dev/null -w "%{http_code}\\n" https://${HOSTS[0]}/

Cluster wieder abbauen (stoppt die Kosten):
       ./k8s/teardown-cluster.sh
────────────────────────────────────────────────────────────────────
EOF
