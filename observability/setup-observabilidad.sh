#!/usr/bin/env bash
# Stack de observabilidad del microservicio pagos-svc.
# Requisitos: cluster Kubernetes funcionando (EKS o minikube) y kubectl apuntando a el.
set -euo pipefail

NAMESPACE="monitoring"
cd "$(dirname "$0")"

echo "==> Agregando repos Helm"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "==> Creando namespace ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Instalando kube-prometheus-stack (Prometheus + Grafana)"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --values kube-prometheus-stack-values.yaml \
  --wait

echo "==> Instalando Loki + Promtail (logs)"
helm upgrade --install loki grafana/loki-stack \
  --namespace "${NAMESPACE}" \
  --values loki-values.yaml

echo "==> Instalando Pushgateway (metricas CI/CD)"
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway \
  --namespace "${NAMESPACE}" \
  --wait

echo "==> Registrando datasource de Loki en Grafana"
kubectl apply -f loki-datasource.yaml

echo "==> Registrando ServiceMonitor del Pushgateway"
kubectl apply -f pushgateway-service-monitor.yaml

echo "==> Provisionando dashboard personalizado en Grafana"
kubectl create configmap pagos-dashboard \
  --from-file=pagos-dashboard.json=dashboards/pagos-dashboard.json \
  --namespace "${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label configmap pagos-dashboard -n "${NAMESPACE}" grafana_dashboard="1" --overwrite

echo ""
echo "==> Listo. Accesos:"
echo "Grafana:     kubectl -n ${NAMESPACE} port-forward svc/prometheus-grafana 3000:80"
echo "             (http://localhost:3000  usuario: admin  contrasena: admin)"
echo "Pushgateway: kubectl -n ${NAMESPACE} get svc pushgateway-prometheus-pushgateway"
echo ""
echo "IMPORTANTE: copia la URL externa del pushgateway (LoadBalancer) al secret"
echo "PUSHGATEWAY_URL del repositorio para que el pipeline pueda publicar las"
echo "metricas de CI/CD (tiempo de despliegue y cobertura)."
