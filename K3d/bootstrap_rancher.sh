#!/usr/bin/env bash

# Define script variable.
CYAN="\033[1;96m"
NORMAL="\033[0m"

# Display message banner.
echo -e "${CYAN}"
cat << "STOP"
  _  ______      _ 
 | |/ /___ \    | |
 | ' /  __) | __| |
 |  <  |__ < / _` |
 | . \ ___) | (_| |
 |_|\_\____/ \__,_|
                   
STOP
echo -e "${NORMAL}"

echo -e "\e[34;1m[🟡] Creating K3D cluster...\e[0m"
k3d cluster create dev \
  --servers 1 \
  --agents 2 \
  --port 80:80@loadbalancer \
  --port 443:443@loadbalancer

echo -e "\e[34;1m[🟡] Configuring kubectl context...\e[0m"
export KUBECONFIG=$(k3d kubeconfig write dev)

echo -e "\e[34;1m[🟡] Installing Helm...\e[0m"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo -e "\e[34;1m[🟡] Adding Helm repos...\e[0m"
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo -e "\e[34;1m[🟡] Installing cert-manager...\e[0m"
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.13.3 \
  --set installCRDs=true

echo -e "\e[34;1m[🟡] Installing Rancher...\e[0m"
kubectl create namespace cattle-system
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.localhost \
  --set replicas=1 \
  --set bootstrapPassword=admin

echo -e "\e[32;1m[🟢] All done! Nodes:\e[0m"
kubectl get nodes -o wide
