#!/usr/bin/env bash
#
# Wendet die ClusterIssuer aus 07-tls-issuer.yaml an und setzt dabei die
# ACME-Adresse aus der lokalen .env ein.
#
# Warum ueberhaupt ein Skript: 07-tls-issuer.yaml ist versioniert und enthaelt
# deshalb nur den Platzhalter PLACEHOLDER_ACME_EMAIL — eine Personendaten-Adresse
# gehoert nicht in ein eingechecktes Manifest. Die Ersetzung laeuft ueber stdin,
# es entsteht also keine gerenderte Datei auf der Platte.
#
# Voraussetzung: cert-manager ist installiert (bringt die ClusterIssuer-CRD mit).
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${REPO_ROOT}/k8s/07-tls-issuer.yaml"
ENV_FILE="${REPO_ROOT}/.env"

# Optional: Kontext erzwingen, damit der Issuer nicht versehentlich in einem
# anderen Cluster landet. ClusterIssuer sind clusterweit, ein Fehlgriff waere
# nicht auf einen Namespace begrenzt.
#
# Kein Array fuer die kubectl-Argumente: "${arr[@]}" liefert unter macOS'
# vorinstalliertem bash 3.2 (kein bash 4.4+) bei einem LEEREN Array unter
# "set -u" ein einzelnes leeres String-Argument statt null Argumenten - das
# haette kubectl als ungueltiges Kommando interpretiert.
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
