#!/bin/bash

# 确保 bc 已安装
if ! command -v bc > /dev/null; then
    apt install bc -y || yum install bc -y
fi

# 设置全局 RPS 流表条目数
sysctl -w net.core.rps_sock_flow_entries=65536

# 获取 CPU 数量
cc=$(grep -c processor /proc/cpuinfo)
echo "cc=$cc"

# 计算每个队列的流表条目数
rfc=$(echo "65536/$cc" | bc)
echo "rfc=$rfc"

# 写入 rps_flow_cnt，排除 lo 接口
for fileRfc in /sys/class/net/*/queues/rx-*/rps_flow_cnt
do
    # 跳过 lo 接口
    [[ "$fileRfc" == */lo/* ]] && continue
    if [ -f "$fileRfc" ]; then
        echo "$rfc" > "$fileRfc"
        echo "Wrote $rfc to $fileRfc"
    else
        echo "No rps_flow_cnt files found"
    fi
done

# 计算 rps_cpus 掩码长度
hex_len=$(( (cc + 3) / 4 ))
echo "hex_len=$hex_len"

# 生成掩码
mask=$(printf '%*s' "$hex_len" | tr ' ' 'f')
echo "mask=$mask"

# 写入 rps_cpus，排除 lo 接口
for fileRps in /sys/class/net/*/queues/rx-*/rps_cpus
do
    # 跳过 lo 接口
    [[ "$fileRps" == */lo/* ]] && continue
    if [ -f "$fileRps" ]; then
        echo "$mask" > "$fileRps"
        echo "Wrote $mask to $fileRps"
    else
        echo "No rps_cpus files found"
    fi
done
