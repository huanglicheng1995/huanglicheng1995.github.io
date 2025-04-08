#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 安装依赖
echo "正在安装依赖..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y wget unzip
elif command -v yum >/dev/null 2>&1; then
    yum update -y
    yum install -y wget unzip
else
    echo "不支持的操作系统，请手动安装依赖"
    exit 1
fi

# 创建工作目录
WORK_DIR="/opt/usque"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 下载最新版本
echo "正在下载usque..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/Diniboy1123/usque/releases/latest | grep "tag_name" | cut -d '"' -f 4)
if [ -z "$LATEST_RELEASE" ]; then
    echo "无法获取最新版本信息"
    exit 1
fi

# 检测系统架构
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
else
    echo "不支持的架构: $ARCH"
    exit 1
fi

# 下载对应架构的二进制文件
DOWNLOAD_URL="https://github.com/Diniboy1123/usque/releases/download/${LATEST_RELEASE}/usque_${LATEST_RELEASE}_linux_${ARCH}.zip"
echo "下载地址: $DOWNLOAD_URL"
wget -O usque.zip "$DOWNLOAD_URL"

# 解压文件
echo "正在解压文件..."
unzip -o usque.zip
chmod +x usque

# 创建systemd服务
cat > /etc/systemd/system/usque.service << EOF
[Unit]
Description=Usque SOCKS5 Proxy Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/usque socks -p 12500
Restart=always
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
systemctl daemon-reload

# 注册服务
echo "正在注册usque服务..."
$WORK_DIR/usque register

# 启动服务
echo "正在启动usque服务..."
systemctl enable usque
systemctl start usque

# 等待服务启动
sleep 5

# 检查服务状态
echo "检查服务状态..."
if systemctl is-active --quiet usque; then
    echo "服务启动成功！"
else
    echo "服务启动失败，请检查日志："
    journalctl -u usque -n 50
    exit 1
fi

echo "安装完成！"
echo "SOCKS5代理已配置在端口12500"
echo "使用方法：socks5://localhost:12500" 
