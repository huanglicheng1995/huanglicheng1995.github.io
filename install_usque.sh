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
    apt-get install -y git golang-go build-essential
elif command -v yum >/dev/null 2>&1; then
    yum update -y
    yum install -y git golang gcc make
else
    echo "不支持的操作系统，请手动安装依赖"
    exit 1
fi

# 检查Go版本
if ! command -v go >/dev/null 2>&1; then
    echo "Go未安装，正在安装最新版本..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y golang-go
    elif command -v yum >/dev/null 2>&1; then
        yum install -y golang
    fi
fi

# 创建工作目录
WORK_DIR="/opt/usque"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 克隆并编译usque
echo "正在下载并编译usque..."
git clone https://github.com/Diniboy1123/usque.git
cd usque
go build -o usque

# 创建配置文件
cat > config.yaml << EOF
proxy:
  type: socks5
  listen: "0.0.0.0:12500"
EOF

# 创建systemd服务
cat > /etc/systemd/system/usque.service << EOF
[Unit]
Description=Usque SOCKS5 Proxy Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORK_DIR/usque
ExecStart=$WORK_DIR/usque/usque -config config.yaml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
systemctl daemon-reload

# 启动服务
echo "正在启动usque服务..."
systemctl enable usque
systemctl start usque

# 检查服务状态
echo "检查服务状态..."
systemctl status usque

echo "安装完成！"
echo "SOCKS5代理已配置在端口12500"
echo "使用方法：socks5://localhost:12500" 
