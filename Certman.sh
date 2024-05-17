#!/bin/bash

set -e

##################################################################################
# Bash script that automates installing Cert-Manager and Rancher on EKS cluster. #
##################################################################################

echo "Installing Cert-Manager..."

# Install Cert-Manager.
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml

# Jetstack Helm repository.
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install Helm Cert-Manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.1.0

echo "Cert-Manager installed successfully."

echo "Installing Rancher..."

# Rancher Helm chart.
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# Namespace for Rancher
kubectl create namespace cattle-system

# Install Helm Rancher.
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.my.org

echo "Rancher installed successfully."
