#!/bin/bash

set -e

kubectl create namespace argocd \
--dry-run=client -o yaml | kubectl apply -f -

helm repo add argo https://argoproj.github.io/argo-helm

helm repo update

helm upgrade --install argocd argo/argo-cd \
--namespace argocd \
--create-namespace

kubectl rollout status deployment argocd-server -n argocd