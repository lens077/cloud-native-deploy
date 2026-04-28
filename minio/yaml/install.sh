#!/usr/bin/env bash
# 启用 POSIX 模式并设置严格的错误处理机制
set -o posix errexit -o pipefail

mkdir -p /home/kubernetes/minio
cd /home/kubernetes/minio

cat >minio-tls.yml<<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-tls-cert
  namespace: minio
spec:
  secretName: minio-tls-secret
  dnsNames:
    - "minio-ui.sumery.com"
    - "minio-api.sumery.com"
  issuerRef:
    name: selfsigned-issuer # 引用 ClusterIssuer
    kind: ClusterIssuer
    group: cert-manager.io
EOF

cat > minio-gateway.yml <<EOF

EOF
cat > minio-routes.yml <<EOF

EOF

kubectl apply -f minio-tls.yml -n minio
kubectl apply -f minio-gateway.yml -n minio
kubectl apply -f minio-routes.yml -n minio
