#!/bin/bash

set -e

helm repo add prometheus-community \
https://prometheus-community.github.io/helm-charts

helm repo add grafana \
https://grafana.github.io/helm-charts

helm repo update

kubectl apply -f kubernetes/monitoring/namespace.yaml

helm upgrade --install kube-prometheus-stack \
prometheus-community/kube-prometheus-stack \
-n monitoring \
-f kubernetes/monitoring/prometheus-values.yaml

helm upgrade --install loki \
grafana/loki-stack \
-n monitoring \
-f kubernetes/monitoring/loki-values.yaml