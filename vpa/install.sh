#!/usr/bin/env bash
# 启用 POSIX 模式并设置严格的错误处理机制
set -o posix errexit -o pipefail

# 1. 克隆官方仓库
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler

# 2. 运行官方安装脚本
./hack/vpa-up.sh

# 3. 验证安装 (查看 vpa-* Pod 是否为 Running 状态)
kubectl get pods -n kube-system | grep vpa

# 支持updateMode: "InPlace"模式需要
kubectl patch deployment vpa-admission-controller -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--feature-gates=InPlace=true"}]'
kubectl patch deployment vpa-updater -n kube-system --patch '
spec:
  template:
    spec:
      containers:
      - name: updater
        args:
        - --v=4
        - --feature-gates=InPlace=true
'
