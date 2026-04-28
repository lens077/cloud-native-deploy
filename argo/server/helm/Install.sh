#!/usr/bin/env bash
# 启用 POSIX 模式并设置严格的错误处理机制
set -o posix errexit -o pipefail

# https://github.com/argoproj/argo-helm/tree/main

mkdir -pv /home/kubernetes/argocd
cd /home/kubernetes/argocd

#git clone --depth 1 https://github.com/argoproj/argo-helm.git
helm repo add argo https://argoproj.github.io/argo-helm
helm pull argo/argo-cd
tar -zxvf argo-cd-*.tgz

cat > new-values.yaml <<EOF
controller:
  replicas: 1

server:
  ## Argo CD server Horizontal Pod Autoscaler
  autoscaling:
    enabled: false
    minReplicas: 2

repoServer:
  autoscaling:
    enabled: false
    minReplicas: 2

applicationSet:
  replicas: 1

server:
  replicas: 1
  service:
    type: LoadBalancer
  ingress:
    enabled: false
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
#    extraTls:
#      - hosts:
#        - argocd.example.com
#        # Based on the ingress controller used secret might be optional
#        secretName: wildcard-tls
EOF

helm upgrade --install argocd \
./argo-cd \
-n argocd \
--create-namespace \
-f new-values.yaml

