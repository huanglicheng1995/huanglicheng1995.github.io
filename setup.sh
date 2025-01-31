#!/bin/bash

# 安装基础工具
echo "安装基础工具：wget, curl, unzip, jq..."
apt update -y && apt install wget curl unzip jq -y

# 安装 Docker
echo "安装 Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
systemctl enable docker

# 设置中国上海时间
echo "设置时区为 Asia/Shanghai..."
timedatectl set-timezone Asia/Shanghai

# 修改 SSH 端口
echo "修改 SSH 端口为 22134..."
sudo sed -i 's/^#Port 22/Port 22134/' /etc/ssh/sshd_config && sudo systemctl restart ssh

# 随机生成主机名
echo "随机生成主机名..."
sudo hostnamectl set-hostname "$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)"

# 关闭系统自动更新（适用于 AWS）
echo "关闭系统自动更新..."
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades

# 应用 BBR 和高级网络优化参数
echo "应用 BBR 和高级网络优化参数..."
cat <<EOF | sudo tee /etc/sysctl.conf
# 基础网络转发配置
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# 禁用反向路径过滤
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0

# 禁用 ICMP 重定向
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

# 禁用发送 ICMP 重定向
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0

# 启用 BBR 拥塞控制算法
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# 增加 TCP 缓冲区大小
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# 增加 UDP 缓冲区大小
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# 启用 TCP Fast Open
net.ipv4.tcp_fastopen=3

# 启用 MTU 探测
net.ipv4.tcp_mtu_probing=1

# 增加本地端口范围
net.ipv4.ip_local_port_range=1024 65535

# 增加 SYN 和 TIME-WAIT 连接的最大数量
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=2000000

# 减少 TIME-WAIT 连接的时间
net.ipv4.tcp_fin_timeout=15

# 启用 TCP 时间戳
net.ipv4.tcp_timestamps=1

# 启用 TCP 窗口缩放
net.ipv4.tcp_window_scaling=1

# 启用 TCP SACK
net.ipv4.tcp_sack=1

# 启用 TCP ECN
net.ipv4.tcp_ecn=1

# 增加最大连接跟踪数
net.netfilter.nf_conntrack_max=1048576

# 增加文件描述符限制
fs.file-max=1048576
EOF

# 应用 sysctl 配置
sudo sysctl -p

echo "脚本执行完成！"
