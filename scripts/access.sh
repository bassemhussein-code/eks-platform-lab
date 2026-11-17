#!/usr/bin/env bash
# Open the UIs with port-forwards (nothing exposed to the internet).
set -euo pipefail

echo "Argo CD  -> http://localhost:8080   user: admin"
echo -n "  password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

echo "Grafana  -> http://localhost:3000   user: admin"
echo -n "  password: "
kubectl -n monitoring get secret -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].data.admin-password}' | base64 -d; echo

echo "Prometheus -> http://localhost:9090"
echo
echo "Ctrl+C to stop all port-forwards"

kubectl -n argocd port-forward svc/argocd-server 8080:80 >/dev/null &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 >/dev/null &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090 >/dev/null &
wait
