#!/bin/bash
set -x

vgs

sudo losetup -f /openebs-lvm-pool.img --show

lvdisplay

#查看所有回环设备 (List all)
sudo losetup -a

#查看指定设备的信息 (List a specific device)
#如果你只想确认 /dev/loop2 的状态：
sudo losetup /dev/loop2

#删除指定回环设备
#如果 /dev/loop2 上没有活动的文件系统或 LVM：
# 使用 -d 选项解除 /dev/loop2 和文件的关联
sudo losetup -d /dev/loop2

set +x
