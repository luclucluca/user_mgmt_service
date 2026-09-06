#!/usr/bin/env bash
# Wendet die ClusterIssuer aus 07-tls-issuer.yaml an, ACME-Adresse per stdin aus .env eingesetzt (kein Klartext im Git).
# Voraussetzung: cert-manager ist installiert (bringt die ClusterIssuer-CRD mit).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${REPO_ROOT}/k8s/07-tls-issuer.yaml"
ENV_FILE="${REPO_ROOT}/.env"

# Optional: Kontext erzwingen, ClusterIssuer sind clusterweit und ein Fehlgriff nicht auf einen Namespace begrenzt.
# Kein Array: leere Arrays liefern unter macOS' bash 3.2 mit "set -u" ein leeres String-Argument statt keinem.
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
kc() {
  if [ -n "${KUBE_CONTEXT}" ]; then
    kubectl --context "${KUBE_CONTEXT}" "$@"
  else
    kubectl "$@"
  fi
}

[ -f "${MANIFEST}" ] || { echo "FEHLER: ${MANIFEST} nicht gefunden"; exit 1; }
[ -f "${ENV_FILE}" ] || { echo "FEHLER: ${ENV_FILE} nicht gefunden"; exit 1; }

ACME_EMAIL=$(grep -E '^ACME_EMAIL=' "${ENV_FILE}" | cut -d= -f2- || true)
if [ -z "${ACME_EMAIL}" ]; then
  echo "FEHLER: ACME_EMAIL ist in ${ENV_FILE} nicht gesetzt."
  echo "Let's Encrypt verlangt eine Adresse fuer das ACME-Konto."
  exit 1
fi

if ! kc get crd clusterissuers.cert-manager.io >/dev/null 2>&1; then
  echo "FEHLER: CRD clusterissuers.cert-manager.io fehlt — cert-manager zuerst installieren."
  exit 1
fi

sed "s|PLACEHOLDER_ACME_EMAIL|${ACME_EMAIL}|" "${MANIFEST}" \
  | kc apply -f -

kc get clusterissuer
