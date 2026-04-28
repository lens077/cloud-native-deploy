helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# https://github.com/jaegertracing/helm-charts/blob/main/charts/jaeger/values.yaml
cat > jaeger-values.yml <<EOF
jaeger:
  enabled: true
  replicas: 1
  resources:
    limits:
      cpu: 1
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 512Mi
  service:
    type: ClusterIP
  ingress:
    enabled: false

# https://github.com/jaegertracing/jaeger/blob/main/cmd/jaeger/config.yaml
userconfig:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    jaeger:
      protocols:
        grpc:
          endpoint: 0.0.0.0:14250
        thrift_http:
          endpoint: 0.0.0.0:14268
    zipkin:
      endpoint: 0.0.0.0:9411

  extensions:
    healthcheckv2:
      use_v2: true
      http:
        endpoint: 0.0.0.0:13133
    jaeger_storage:
      backends:
        primary_store:
          elasticsearch:
            server_urls: ["http://elasticsearch-es-http.elastic-stack:9200"]
            auth:
              basic:
                username: elastic
                password: XwjLbwoaCLvuJ7PwaAWtBkNO
            indices:
              index_prefix: "ecommerce"
    jaeger_query:
      storage:
        traces: primary_store

  exporters:
    jaeger_storage_exporter:
      trace_storage: primary_store

  processors:
    batch: {}

  service:
    extensions: [jaeger_storage, jaeger_query, healthcheckv2]
    pipelines:
      traces:
        receivers: [otlp, jaeger, zipkin]
        processors: [batch]
        exporters: [jaeger_storage_exporter]
    telemetry:
      metrics:
        level: detailed
        readers:
          - pull:
              exporter:
                prometheus:
                  host: 0.0.0.0
                  port: 8888

storage:
  type: elasticsearch
  elasticsearch:
    url: http://elasticsearch-es-http.elastic-stack:9200
    user: elastic
    password: XwjLbwoaCLvuJ7PwaAWtBkNO
    tls:
      enabled: false

esIndexCleaner:
  enabled: true
  numberOfDays: 7
  schedule: "0 0 * * *"
  extraEnv:
    - name: INDEX_PREFIX
      value: "ecommerce"

EOF

# helm uninstall jaeger -n observability
helm upgrade --install jaeger ./jaeger \
  --reset-values \
  --create-namespace \
  -n observability \
  -f jaeger-values.yml
