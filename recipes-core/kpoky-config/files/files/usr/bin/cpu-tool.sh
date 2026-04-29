#!/bin/sh
# Acropi RK3566 CPU/GPU 性能管理工具

# 定义路径
CPU_PATH="/sys/devices/system/cpu/cpufreq/policy0"
GPU_PATH="/sys/class/devfreq/fde60000.gpu"
TZ_CPU="/sys/class/thermal/thermal_zone0"
TZ_GPU="/sys/class/thermal/thermal_zone1"

show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  status    - 查看 CPU/GPU 当前频率、温度和调频策略"
    echo "  monitor   - 实时监控 CPU/GPU 状态 (每秒更新)"
    echo "  list      - 列出支持的所有频率挡位"
    echo "  set-freq  - 设置固定频率 (例如: cpu-tool set-freq 1416000)"
    echo "  max       - 开启全性能模式 (CPU 1.8GHz / GPU 800MHz)"
    echo "  auto      - 恢复自动调频模式"
}

get_status() {
    CUR_CPU_F=$(cat $CPU_PATH/scaling_cur_freq 2>/dev/null || echo 0)
    CUR_CPU_G=$(cat $CPU_PATH/scaling_governor 2>/dev/null || echo "N/A")
    CUR_CPU_T=$(cat $TZ_CPU/temp 2>/dev/null || echo 0)
    
    CUR_GPU_F=$(cat $GPU_PATH/cur_freq 2>/dev/null || echo 0)
    CUR_GPU_G=$(cat $GPU_PATH/governor 2>/dev/null || echo "N/A")
    CUR_GPU_T=$(cat $TZ_GPU/temp 2>/dev/null || echo 0)

    echo "--- CPU 状态 ---"
    echo "频率: $((CUR_CPU_F / 1000)) MHz | 温度: $((CUR_CPU_T / 1000)) °C | 策略: $CUR_CPU_G"
    echo "--- GPU 状态 ---"
    echo "频率: $((CUR_GPU_F / 1000000)) MHz | 温度: $((CUR_GPU_T / 1000)) °C | 策略: $CUR_GPU_G"
}

case "$1" in
    status)
        get_status
        ;;
    monitor)
        echo "正在监控 Acropi RK3566 (按 Ctrl+C 退出)..."
        printf "%-10s %-8s | %-10s %-8s\n" "CPU(MHz)" "Temp" "GPU(MHz)" "Temp"
        echo "------------------------------------------------"
        while true; do
            C_F=$(cat $CPU_PATH/scaling_cur_freq 2>/dev/null)
            C_T=$(cat $TZ_CPU/temp 2>/dev/null)
            G_F=$(cat $GPU_PATH/cur_freq 2>/dev/null)
            G_T=$(cat $TZ_GPU/temp 2>/dev/null)
            printf "%-10s %-8s | %-10s %-8s\r" "$((C_F / 1000))" "$((C_T / 1000))°C" "$((G_F / 1000000))" "$((G_T / 1000))°C"
            sleep 1
        done
        ;;
    list)
        echo "--- CPU 可用频率 ---"
        cat $CPU_PATH/scaling_available_frequencies
        echo "--- GPU 可用频率 ---"
        cat $GPU_PATH/available_frequencies
        ;;
    set-freq)
        if [ -z "$2" ]; then echo "请指定 CPU 频率 (kHz)"; exit 1; fi
        echo userspace > $CPU_PATH/scaling_governor
        echo "$2" > $CPU_PATH/scaling_setspeed
        echo "CPU 频率已固定为: $2 kHz"
        ;;
    max)
        echo performance > $CPU_PATH/scaling_governor
        echo performance > $GPU_PATH/governor
        echo "已开启最高性能模式 (CPU & GPU 打满)"
        ;;
    auto)
        echo ondemand > $CPU_PATH/scaling_governor
        echo simple_ondemand > $GPU_PATH/governor
        echo "已恢复自动调频模式"
        ;;
    *)
        show_help
        ;;
esac
