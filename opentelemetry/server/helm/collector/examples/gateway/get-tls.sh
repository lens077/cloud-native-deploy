#!/usr/bin/env bash
# 启用 POSIX 模式并设置严格的错误处理机制
set -o posix errexit -o pipefail

k8s_postgres_secret="observability-root-ca-secret"
ns=observability
kubectl get secret -n $ns
kubectl get secret ${k8s_postgres_secret} -n $ns \
   -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret ${k8s_postgres_secret} -n $ns \
   -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
kubectl get secret ${k8s_postgres_secret} -n $ns \
   -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

openssl x509 -in ca.crt -noout -text
