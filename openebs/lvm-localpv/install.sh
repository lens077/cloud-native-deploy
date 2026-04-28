#!/bin/bash
# https://openebs.io/docs/quickstart-guide/prerequisites

# 创建一个200GB的映像文件
#truncate -s 30G /tmp/disk.img
#
## 将映像文件关联到环回设备（例如 /dev/loop0）
#sudo losetup -f /tmp/disk.img --show
#
## 将环回设备（或你的物理磁盘）创建为物理卷（PV）
#sudo pvcreate /dev/loop0
#
## 创建一个名为 lvmvg 的卷组（VG）
#sudo vgcreate lvmvg /dev/loop0

sudo truncate -s 200G /openebs-lvm-pool.img 
sudo losetup -f /openebs-lvm-pool.img  --show
sudo pvcreate /dev/loop0
sudo vgcreate lvmvg /dev/loop0
sudo vgs

# # 查找并卸载所有指向 /openebs-lvm-pool.img 的 loop 设备
#sudo losetup -a | grep /openebs-lvm-pool.img | cut -d: -f1 | xargs -r sudo losetup -d
cat > /etc/systemd/system/openebs-lvm-init.service <<EOF
[Unit]
Description=OpenEBS LVM Pool Initialization
Requires=local-fs.target
After=network-online.target local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
# 1. 启动时，找到一个空闲 loop 设备并挂载文件
ExecStartPre=/usr/sbin/losetup -f /openebs-lvm-pool.img
# 2. 激活 LVM 卷组
ExecStart=/sbin/vgchange -ay lvmvg
# 3. 验证 VG 状态
ExecStartPost=/sbin/vgs

# 停止时的逻辑：禁用 VG，然后卸载 Loop 设备
ExecStop=/bin/sh -c '/sbin/vgchange -an lvmvg; \
                    LOOP_DEV=$("/usr/sbin/losetup" -j /openebs-lvm-pool.img | cut -d: -f1); \
                    if [ -n "$LOOP_DEV" ]; then \
                        "/usr/sbin/losetup" -d "$LOOP_DEV"; \
                    fi'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable openebs-lvm-init.service
sudo systemctl start openebs-lvm-init.service


# 按照 OpenEBS 的文档，使用 Helm 安装 lvm-localpv 驱动程序，并确保在 StorageClass 配置中将 volgroup 名称设置为 lvmvg。
# --set engines.local.lvm.enabled=true \ 逻辑卷
# --set engines.local.zfs.enabled=false \ 不安装zfs
#  --set engines.replicated.mayastor.enabled=false 不安装replicated， 即复制卷， 这是高可用的基础，对于单机价值不大
helm repo add openebs https://openebs.github.io/openebs
helm repo update

helm pull openebs/openebs
tar -zxvf openebs-*.tgz

helm install openebs ./openebs --namespace openebs --create-namespace \
  --set engines.local.lvm.enabled=true \
  --set engines.local.zfs.enabled=false \
  --set engines.replicated.mayastor.enabled=false

# 创建lvm的sc https://openebs.io/docs/user-guides/local-storage-user-guide/local-pv-lvm/configuration/lvm-create-storageclass#lvm-supported-storageclass-parameters
cat > lvm-sc.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-lvmpv
parameters:
  storage: "lvm"
  volgroup: "lvmvg"
provisioner: local.csi.openebs.io
EOF
kubectl apply -f lvm-sc.yaml

kubectl get sc
#NAME                    PROVISIONER            RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
#openebs-hostpath        openebs.io/local       Delete          WaitForFirstConsumer   false                  6m49s
#openebs-loki-localpv    openebs.io/local       Delete          WaitForFirstConsumer   false                  6m49s
#openebs-lvmpv           local.csi.openebs.io   Delete          Immediate              false                  3s
#openebs-minio-localpv   openebs.io/local       Delete          WaitForFirstConsumer   false                  6m49s

# 测试lvm：
cat > test-lvm-pvc.yml <<EOF
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-lvm-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi  # 请求1GiB的存储空间
  storageClassName: openebs-lvmpv
EOF
kubectl apply -f test-lvm-pvc.yml
#persistentvolumeclaim/my-lvm-pvc created

kubectl get pvc my-lvm-pvc
#NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
#my-lvm-pvc   Bound    pvc-579efed2-b65a-498f-929b-e8cda10b97b9   1Gi        RWO            openebs-lvmpv   <unset>                 6s

cat > pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: default
spec:
  containers:
  - name: my-app-container
    image: busybox
    command: ["/bin/sh", "-c", "echo Hello from OpenEBS LVM!; sleep 3600"]
    volumeMounts:
    - name: my-lvm-storage
      mountPath: "/data"
  volumes:
  - name: my-lvm-storage
    persistentVolumeClaim:
      claimName: my-lvm-pvc
EOF
kubectl apply -f pod.yaml
kubectl get po -owide

kubectl logs my-app
#Hello from OpenEBS LVM!

# 使用lvdisplay查看对应Pod所在的节点的LV Name是否存在pvc-xx开头的，如果存在，说明lvm逻辑卷没问题
lvdisplay
sudo vgs

# 设置为默认的SC
kubectl patch storageclass openebs-lvmpv \
-p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

set +x
