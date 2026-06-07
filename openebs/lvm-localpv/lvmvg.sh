#!/bin/bash

# 1. 确认空闲空间起始位置（例如, 68.7GB 到 275GB）
sudo parted /dev/sda print free

# 2. 创建新分区覆盖全部空闲空间（例如, 68.7GB 到 275GB）
sudo parted /dev/sda mkpart primary 68.7GB 100%

# 查看当前分区情况
sudo parted /dev/sda print free
# 如果新分区为 /dev/sda4
sudo parted /dev/sda set 4 lvm on
sudo partprobe /dev/sda

# 3. 创建物理卷和卷组
sudo pvcreate /dev/sda4
sudo vgcreate lvmvg /dev/sda4

# 4. 验证
sudo vgs lvmvg   # 应显示约 206GB 容量
