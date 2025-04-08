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
    apt-get install -y wget unzip curl
elif command -v yum >/dev/null 2>&1; then
    yum update -y
    yum install -y wget unzip curl
else
    echo "不支持的操作系统，请手动安装依赖"
    exit 1
fi

# 创建工作目录
WORK_DIR="/opt/usque"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 清理旧文件
echo "清理旧文件..."
rm -rf usque usque.zip

# 下载最新版本
echo "正在下载usque..."
# 使用curl获取最新版本信息
LATEST_RELEASE=$(curl -s https://api.github.com/repos/Diniboy1123/usque/releases/latest | grep "tag_name" | cut -d '"' -f 4)
if [ -z "$LATEST_RELEASE" ]; then
    echo "无法获取最新版本信息，尝试使用固定版本..."
    LATEST_RELEASE="v1.0.2"  # 使用已知的最新版本
fi

echo "使用版本: $LATEST_RELEASE"

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
DOWNLOAD_URL="https://github.com/Diniboy1123/usque/releases/download/${LATEST_RELEASE}/usque_${LATEST_RELEASE#v}_linux_${ARCH}.zip"
echo "下载地址: $DOWNLOAD_URL"

# 使用curl下载文件
curl -L -o usque.zip "$DOWNLOAD_URL"

# 检查下载是否成功
if [ ! -f "usque.zip" ] || [ ! -s "usque.zip" ]; then
    echo "下载失败，尝试直接下载二进制文件..."
    # 尝试直接下载二进制文件
    curl -L -o usque "https://github.com/Diniboy1123/usque/releases/download/${LATEST_RELEASE}/usque_${LATEST_RELEASE#v}_linux_${ARCH}"
    chmod +x usque
else
    # 检查zip文件内容
    echo "检查下载的文件内容..."
    unzip -l usque.zip
    
    # 解压文件
    echo "正在解压文件..."
    unzip -o usque.zip
    
    # 检查解压后的文件
    echo "检查解压后的文件..."
    ls -la
    
    # 查找可执行文件
    echo "查找可执行文件..."
    find . -type f -name "usque" -executable
    
    # 如果找到可执行文件，复制到工作目录
    if [ -f "usque" ]; then
        echo "找到可执行文件，设置权限..."
        chmod +x usque
    else
        echo "在当前目录未找到可执行文件，尝试在其他位置查找..."
        # 在其他位置查找
        find . -type f -name "usque" | while read -r file; do
            echo "找到文件: $file"
            cp "$file" .
            chmod +x usque
            break
        done
    fi
fi

# 检查可执行文件是否存在
if [ ! -f "usque" ] || [ ! -x "usque" ]; then
    echo "无法找到可执行文件，安装失败"
    echo "当前目录内容："
    ls -la
    exit 1
fi

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
