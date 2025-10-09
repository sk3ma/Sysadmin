#!/usr/bin/env bash

set -euo pipefail

GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"
ARGO_NAMESPACE="argocd"
ARGO_HOST="argocd.mycompany.com"
INGRESS_CLASS="nginx"
TLS_SECRET="argocd-tls"
ARGO_VERSION="stable"

echo -e "${GREEN} Creating namespace '${ARGO_NAMESPACE}'...${RESET}"
kubectl create namespace "${ARGO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN} Installing ArgoCD manifests...${RESET}"
kubectl apply -n "${ARGO_NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_VERSION}/manifests/install.yaml"

echo -e "${GREEN} Waiting for ArgoCD pods...${RESET}"
kubectl wait --for=condition=available --timeout=180s deployment --all -n "${ARGO_NAMESPACE}" || {
  echo -e "${RED} ArgoCD deployments failed to become ready.${RESET}"
  exit 1
}

if ! kubectl get secret "${TLS_SECRET}" -n "${ARGO_NAMESPACE}" >/dev/null 2>&1; then
  echo -e "${GREEN} Creating temporary self-signed TLS secret '${TLS_SECRET}'...${RESET}"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/argocd.key -out /tmp/argocd.crt \
    -subj "/CN=${ARGO_HOST}/O=ArgoCD"
  kubectl create secret tls "${TLS_SECRET}" \
    --namespace "${ARGO_NAMESPACE}" \
    --key /tmp/argocd.key \
    --cert /tmp/argocd.crt
  rm -f /tmp/argocd.key /tmp/argocd.crt
fi

echo -e "${GREEN} Creating Ingress for ArgoCD...${RESET}"
cat << STOP | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: ${ARGO_NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: ${INGRESS_CLASS}
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - ${ARGO_HOST}
      secretName: ${TLS_SECRET}
  rules:
    - host: ${ARGO_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
STOP

sleep 5
kubectl get ingress -n "${ARGO_NAMESPACE}"

echo -e "${GREEN} Retrieving ArgoCD password...${RESET}"
if kubectl get secret argocd-initial-admin-secret -n "${ARGO_NAMESPACE}" >/dev/null 2>&1; then
  ARGO_PWD=$(kubectl -n "${ARGO_NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
else
  echo -e "${YELLOW} Password secret not found, possibly rotated or removed.${RESET}"
  ARGO_PWD="(already changed)"
fi

if ! command -v argocd &> /dev/null; then
  echo -e "${GREEN} Installing ArgoCD CLI...${RESET}"
  curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
  chmod +x /usr/local/bin/argocd
fi

if [ "${ARGO_PWD}" != "(already changed)" ]; then
  echo -e "${GREEN} Logging into ArgoCD...${RESET}"
  argocd login "${ARGO_HOST}" --username admin --password "${ARGO_PWD}" --insecure || true
fi

echo -e "${CYAN}
Link: https://${ARGO_HOST}
Username: admin
Password: ${ARGO_PWD}
${RESET}"
