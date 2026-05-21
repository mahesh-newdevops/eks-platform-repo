#!/bin/bash

set -e

aws eks update-kubeconfig \
--region ap-south-1 \
--name prod-eks

echo "Deploy Namespace"

kubectl apply -f kubernetes/namespace.yaml

echo "Deploy Karpenter"

kubectl apply -f kubernetes/karpenter/

echo "Install ArgoCD"

bash scripts/install_argocd.sh

echo "Install Monitoring"

bash scripts/install_monitoring.sh

echo "Deploy Root App"

kubectl apply -f kubernetes/argocd/root-app.yaml

echo "Bootstrap Completed"