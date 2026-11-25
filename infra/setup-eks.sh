#!/usr/bin/env bash
# Creacion del cluster EKS y configuracion de kubectl.
# Requisitos: AWS CLI y eksctl instalados y con credenciales.
set -euo pipefail
cd "$(dirname "$0")"

REGION="us-east-1"
CLUSTER="pagos-cluster"

echo "==> Creando cluster EKS (tarda ~15-20 minutos)"
eksctl create cluster -f eksctl-cluster.yaml

echo "==> Escribiendo kubeconfig"
eksctl utils write-kubeconfig --cluster "${CLUSTER}" --region "${REGION}"

echo "==> Nodos del cluster"
kubectl get nodes

echo ""
echo "Cluster listo. Siguientes pasos:"
echo "1) Desplegar el microservicio: kubectl apply -f k8s/"
echo "2) Instalar observabilidad:  ../observability/setup-observabilidad.sh"
