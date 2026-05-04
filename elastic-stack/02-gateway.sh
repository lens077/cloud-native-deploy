# gateway
cat > es-gateway.yml <<EOF
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
      mode: Terminate # 在网关层解密
      certificateRefs:
      - name: elastic-stack-tls-secret # 必须与 Certificate 中的 secretName 一致
    allowedRoutes:
      namespaces:
        from: Same
EOF
kubectl apply -f gateway.yml -n elastic-stack

cat > es-httproute.yml <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: elasticsearch-route
  namespace: elastic-stack
spec:
  parentRefs:
  - name: elastic-gateway
  hostnames:
  - "es.sumery.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: elasticsearch-es-http
      port: 9200
EOF
kubectl apply -f es-httproute.yml -n elastic-stack

cat > kibana-httproute.yml <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kibana-route
  namespace: elastic-stack
spec:
  parentRefs:
  - name: elastic-gateway
  hostnames:
  - "kibana.sumery.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: es-kb-quickstart-eck-kibana-kb-http
      port: 5601
EOF
kubectl apply -f kibana-httproute.yml -n elastic-stack

cat > certificate.yml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: elastic-stack-tls
  namespace: elastic-stack
spec:
  secretName: elastic-stack-tls-secret # 证书将存储在这个 Secret 中
  issuerRef:
    name: selfsigned-issuer # 替换为你集群中的 ClusterIssuer 或 Issuer 名称
    kind: ClusterIssuer
  commonName: kibana.sumery.com
  dnsNames:
  - "kibana.sumery.com"
  - "es.sumery.com"
EOF
kubectl apply -f certificate.yml -n elastic-stack
