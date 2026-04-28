#!/bin/bash
set -x
# https://grafana.com/docs/grafana/latest/setup-grafana/installation/helm/


mkdir /home/kubernetes/grafana
cd /home/kubernetes/grafana

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

#kubectl create namespace monitoring
#kubectl create namespace observability

helm pull grafana/grafana
tar -zxvf grafana*.tgz

cat > new-values.yml <<EOF
# https://github.com/grafana-community/helm-charts/blob/main/charts/grafana/values.yaml
persistence:
  type: pvc
  enabled: true
  storageClassName: openebs-lvmpv
  size: 5Gi
service:
  enabled: true
  type: ClusterIP
  # Set the ip family policy to configure dual-stack see [Configure dual-stack](https://kubernetes.io/docs/concepts/services-networking/dual-stack/#services)
  ipFamilyPolicy: ""
  # Sets the families that should be supported and the order in which they should be applied to ClusterIP as well. Can be IPv4 and/or IPv6.
  ipFamilies: []
  loadBalancerIP: ""
  loadBalancerClass: ""
  loadBalancerSourceRanges: []
  port: 80
  targetPort: 3000

EOF

# 默认安装的是使用临时存储
# helm uninstall grafana -n observability
helm upgrade --install grafana ./grafana \
--create-namespace \
-n observability \
-f new-values.yml


# 获取密码, 账号默认是admin
kubectl get secret --namespace observability grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

set +x
