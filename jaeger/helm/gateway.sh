#!/usr/bin/env bash
# 启用 POSIX 模式并设置严格的错误处理机制
set -o posix errexit -o pipefail

cat > jaeger-gateway.yml <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: elastic-gateway
  namespace: elastic-stack
spec:
  gatewayClassName: cilium
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: elastic-stack-tls-secret
    allowedRoutes:
      namespaces:
        from: All # 允许跨 Namespace 关联 Route (因为 Jaeger 在 observability 命名空间)

EOF
kubectl apply -f jaeger-gateway.yml

cat > jaeger-route.yml <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: jaeger-route
  namespace: observability # 建议放在 Jaeger 所在的命名空间
spec:
  parentRefs:
  - name: elastic-gateway
    namespace: elastic-stack # 指向 Gateway 所在的命名空间
    sectionName: https
  hostnames:
  - "jaeger.sumery.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: jaeger # jaeger service 名字
      port: 16686 # Jaeger UI 的标准端口
EOF
kubectl apply -f jaeger-route.yml
