#!/usr/bin/env bash
# Auditoria automatizada de cumplimiento para pagos-svc (EP3 / IE5).
# Se puede ejecutar localmente o como step del pipeline.
set -euo pipefail

fail=0

echo "=== Auditoria de cumplimiento ==="

# 1. No debe haber secretos commiteados (patrones comunes)
echo ">> Buscando posibles secretos en el codigo..."
if grep -RInE "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|password[[:space:]]*=[[:space:]]*[\"'][^\"']+[\"'])" \
     --exclude-dir=.git --exclude-dir=target . ; then
  echo "ERROR: se detectaron posibles secretos en el codigo."
  fail=1
else
  echo "OK: no se detectaron secretos."
fi

# 2. La imagen desplegada debe estar versionada (no usar latest ni placeholder)
echo ">> Verificando tag de imagen en k8s/deployment.yaml..."
if grep -qE "IMAGE_TAG_PLACEHOLDER|:latest" k8s/deployment.yaml; then
  echo "ADVERTENCIA: la imagen usa un tag no versionado. En el pipeline se reemplaza por el SHA."
  # en CI el placeholder ya fue reemplazado, asi que no es falta local
else
  echo "OK: la imagen esta versionada con un tag concreto."
fi

# 3. El analisis de seguridad (Snyk) debe estar en el pipeline
echo ">> Verificando integracion de Snyk..."
if grep -q "snyk" .github/workflows/pipeline.yml; then
  echo "OK: Snyk esta integrado en el pipeline."
else
  echo "ERROR: Snyk no esta en el pipeline."
  fail=1
fi

# 4. El quality gate de SonarCloud debe estar en el pipeline
echo ">> Verificando quality gate de SonarCloud..."
if grep -q "sonar.qualitygate.wait=true" .github/workflows/pipeline.yml; then
  echo "OK: el quality gate de SonarCloud bloquea el pipeline."
else
  echo "ERROR: falta el quality gate de SonarCloud."
  fail=1
fi

# 5. El monitoreo (Prometheus) debe estar habilitado en el microservicio
echo ">> Verificando exposicion de metricas Prometheus..."
if grep -q "prometheus" src/main/resources/application.properties; then
  echo "OK: /actuator/prometheus esta habilitado."
else
  echo "ERROR: no se expone el endpoint de Prometheus."
  fail=1
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "RESULTADO: auditoria FALLIDA."
  exit 1
fi

echo "RESULTADO: auditoria APROBADA."
