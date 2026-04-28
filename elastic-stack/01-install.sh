mkdir -p /home/kubernetes/elastic
cd /home/kubernetes/elastic

helm repo add elastic https://helm.elastic.co
helm repo update

# 前置条件
# https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/install-using-helm-chart
# 集群范围（全局）安装
helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace

# Install an eck-managed Elasticsearch and Kibana using the default values, which deploys the quickstart examples.
helm pull elastic/eck-stack
tar -zxvf eck-stack-*.tgz

# 禁用内部TLS，在网关层来作为tls
cat > es-disable-tls.yml <<EOF
eck-elasticsearch:
  http:
    tls:
      selfSignedCertificate:
        disabled: true

# 禁用 Kibana 内部 TLS
eck-kibana:
  http:
    tls:
      selfSignedCertificate:
        disabled: true
EOF

helm upgrade --install es-kb-quickstart\
  ./eck-stack \
  -n elastic-stack \
  --create-namespace \
  -f es-disable-tls.yml

# 获取默认密码, 账号默认为elastic
kubectl get secret elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}' -n elastic-stack
