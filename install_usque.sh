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

# 设置Go环境变量
echo "设置Go环境变量..."
export GOPATH=/root/go
export GOMODCACHE=$GOPATH/pkg/mod
export PATH=$PATH:$GOPATH/bin
mkdir -p $GOPATH

# 创建工作目录
WORK_DIR="/opt/usque"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 克隆并编译usque
echo "正在下载并编译usque..."
git clone https://github.com/Diniboy1123/usque.git
cd usque

# 初始化Go模块
go mod init usque
go mod tidy

# 编译
go build -o usque

# 检查编译是否成功
if [ ! -f "usque" ]; then
    echo "编译失败，请检查错误信息"
    exit 1
fi

# 设置执行权限
chmod +x usque

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
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
systemctl daemon-reload

# 检查服务文件是否存在
if [ ! -f "/etc/systemd/system/usque.service" ]; then
    echo "服务文件创建失败"
    exit 1
fi

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
