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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="${REPO_ROOT}/k8s"
WORKFLOW="${REPO_ROOT}/.github/workflows/deploy.yml"

info()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m!   %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓   %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
info "Voraussetzungen pruefen"
# ---------------------------------------------------------------------------
for bin in doctl kubectl helm; do
  command -v "$bin" >/dev/null || { echo "FEHLER: $bin nicht gefunden"; exit 1; }
done
doctl account get >/dev/null || { echo "FEHLER: doctl nicht authentifiziert"; exit 1; }
ok "doctl, kubectl, helm vorhanden"

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

HOST="app.${LB_IP}.nip.io"
API_URL="http://${HOST}/api"
ok "LoadBalancer-IP: ${LB_IP}"
ok "Host: ${HOST}"

# ---------------------------------------------------------------------------
info "Host in die Manifests und die Pipeline schreiben"
# ---------------------------------------------------------------------------
# Next.js backt NEXT_PUBLIC_API_URL zur Build-Zeit ein. Der Host muss deshalb an
# zwei Stellen konsistent gehalten werden: im Ingress und im Build-Arg.
sed -i.bak "s|^\( *\)host: .*|\1host: ${HOST}|" "${K8S_DIR}/06-ingress.yaml"
sed -i.bak "s|NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=${API_URL}|" "${WORKFLOW}"
rm -f "${K8S_DIR}/06-ingress.yaml.bak" "${WORKFLOW}.bak"
ok "06-ingress.yaml und deploy.yml aktualisiert"

# ---------------------------------------------------------------------------
info "Manifests ausrollen"
# ---------------------------------------------------------------------------
kubectl apply -f "${K8S_DIR}"

info "Auf PostgreSQL warten"
kubectl wait --for=condition=Ready pod/postgres-0 -n "${NAMESPACE}" --timeout=300s

# ---------------------------------------------------------------------------
info "Status"
# ---------------------------------------------------------------------------
kubectl get pods,svc,pvc,ingress -n "${NAMESPACE}"

cat <<EOF

────────────────────────────────────────────────────────────────────
Infrastruktur steht. Host: http://${HOST}

Backend und Frontend stehen auf ErrImagePull, solange die Images
fehlen. Naechste Schritte:

  1. GHCR-Packages auf 'public' stellen (GitHub -> Packages ->
     Package settings -> Change visibility), sonst wird zusaetzlich
     ein imagePullSecret benoetigt.

  2. Pipeline-Aenderung committen und pushen:
       git add .github/workflows/deploy.yml k8s/
       git commit -m "k8s: ingress host ${HOST}"
       git push

  3. Nach dem Actions-Run die Deployments auf den gebauten Tag setzen:
       SHA=\$(git rev-parse HEAD)
       kubectl set image deployment/backend  backend=ghcr.io/luclucluca/user_mgmt_service-backend:\$SHA  -n ${NAMESPACE}
       kubectl set image deployment/frontend frontend=ghcr.io/luclucluca/user_mgmt_service-frontend:\$SHA -n ${NAMESPACE}

  4. Testen:
       curl -s -o /dev/null -w "%{http_code}\\n" http://${HOST}/

Cluster wieder abbauen (stoppt die Kosten):
       ./k8s/teardown-cluster.sh
────────────────────────────────────────────────────────────────────
EOF
