#!/usr/bin/env bash
# 启用 POSIX 模式并设置严格的错误处理机制
set -o posix errexit -o pipefail
# https://docs.kafka-ui.provectus.io/configuration/helm-charts/quick-start

mkdir -pv /home/kubernetes/kafka
cd /home/kubernetes/kafka

kubectl create ns kafka
wget 'https://strimzi.io/install/latest?namespace=kafka'

kubectl create -f 'latest?namespace=kafka' -n kafka

wget https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml
kubectl apply -f kafka-single-node.yaml -n kafka

kubectl patch svc my-cluster-kafka-bootstrap -p '{"spec":{"type":"LoadBalancer"}}' -n kafka
# test
# send
kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.51.0-kafka-4.2.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic

# 接收， 打开新终端：
kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.51.0-kafka-4.2.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning

#helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
#helm repo update
#helm pull kafka-ui/kafka-ui
#
## 将kafka-cluster-broker-endpoints:9092替换
#cat > helm-kafuka-ui-values.yml <<EOF
#ApplicationConfig:
#  kafka:
#    clusters:
#      - name: yaml
#        bootstrapServers:  my-cluster-kafka-brokers.kafka.svc.cluster.local:9092
#  auth:
#    type: disabled
#  management:
#    health:
#      ldap:
#        enabled: false
#EOF
#
#helm install kafka-ui . -f helm-kafuka-ui-values.yml
#
## https://strimzi.io/docs/operators/latest/deploying#deploying-cluster-operator-helm-chart-str
##指定为 internal 或 cluster-ip（使用每个代理的 Kafka IP 服务公开 Kafka）或外部侦听器的类型，
## 如 route（仅 OpenShift），loadbalancer，nodeport 或 ingress（仅 Kubernetes）。
#
#cat > example.yml <<EOF
#apiVersion: kafka.strimzi.io/v1beta2
#kind: KafkaNodePool
#metadata:
#  name: dual-role
#  labels:
#    strimzi.io/cluster: my-cluster
#spec:
#  replicas: 1
#  roles:
#    - controller
#    - broker
#  storage:
#    type: jbod
#    volumes:
#      - id: 0
#        type: persistent-claim
#        size: 10Gi
#        deleteClaim: false
#        kraftMetadata: shared
#---
#
#apiVersion: kafka.strimzi.io/v1beta2
#kind: Kafka
#metadata:
#  name: my-cluster
#  annotations:
#    strimzi.io/node-pools: enabled
#    strimzi.io/kraft: enabled
#spec:
#  kafka:
#    version: 4.0.0
#    metadataVersion: 4.0-IV3
#    listeners:
#      - name: plain
#        port: 9092
#        type: loadbalancer
#        tls: false
#      - name: tls
#        port: 9093
#        type: loadbalancer
#        tls: true
#    config:
#      offsets.topic.replication.factor: 1
#      transaction.state.log.replication.factor: 1
#      transaction.state.log.min.isr: 1
#      default.replication.factor: 1
#      min.insync.replicas: 1
#  entityOperator:
#    topicOperator: {}
#    userOperator: {}
#EOF
