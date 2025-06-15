#!/bin/bash

# 通用函数库
# 包含日志、权限检查、网络检查等通用功能

# 日志记录函数
log_message() {
    local level=${2:-INFO}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $1" >> "$LOG_FILE"
}

# 初始化日志
init_logging() {
    # 确保日志目录存在
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    # 记录启动信息
    log_message "脚本启动 - 版本: $SCRIPT_VERSION" "INFO"
    log_message "系统: $(echo ${DISTRO^}), 包管理器: $PACKAGE_MANAGER, 服务管理器: $SERVICE_MANAGER" "INFO"
    
    # 日志轮转 - 保持日志文件不超过10MB
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt 10485760 ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        log_message "日志文件已轮转" "INFO"
    fi
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[错误]${NC} 此脚本需要root权限运行，请使用 sudo 执行"
        echo "使用方法: sudo $0"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    print_info "检查网络连接..."
    local network_ok=false
    
    for host in "${NETWORK_TEST_HOSTS[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            network_ok=true
            print_success "网络连接正常 (测试主机: $host)"
            log_message "网络连接测试成功 - $host" "INFO"
            break
        fi
    done
    
    if [[ "$network_ok" == "false" ]]; then
        print_error "网络连接失败，请检查网络设置"
        log_message "网络连接测试失败" "ERROR"
        return 1
    fi
    
    return 0
}

# 等待用户按键继续
wait_for_key() {
    local return_value=${1:-0}
    if [[ $return_value != 0 ]]; then
        echo ""
        echo -ne "${GRAY}按回车键继续...${NC}"
        read -r
    fi
}

# 显示日志
show_logs() {
    clear
    print_header "系统日志"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        print_warning "日志文件不存在"
        return 1
    fi
    
    echo -e "${CYAN}◆ 最近20条日志记录${NC}"
    tail -20 "$LOG_FILE"
    
    echo ""
    echo -e "${CYAN}◆ 日志文件信息${NC}"
    echo "  路径: $LOG_FILE"
    echo "  大小: $(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")"
    echo "  最后修改: $(stat -c %y "$LOG_FILE" 2>/dev/null || echo "未知")"
    
    echo ""
    print_menu_item "1" "查看完整日志"
    print_menu_item "2" "清空日志"
    print_menu_item "3" "搜索日志"
    print_menu_item "0" "返回"
    
    print_prompt "请选择操作 [0-3]: "
    read -r choice
    
    case $choice in
        1) 
            less "$LOG_FILE"
            ;;
        2)
            print_prompt "确定要清空日志吗？(y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$LOG_FILE"
                print_success "日志已清空"
                log_message "日志文件已被清空" "INFO"
            fi
            ;;
        3)
            print_prompt "请输入搜索关键词: "
            read -r keyword
            if [[ -n "$keyword" ]]; then
                echo ""
                echo -e "${CYAN}搜索结果:${NC}"
                grep -i "$keyword" "$LOG_FILE" || print_info "未找到相关记录"
            fi
            ;;
        0) 
            return
            ;;
        *) 
            print_error "无效选择"
            ;;
    esac
    
    wait_for_key 1
}

# 退出脚本
exit_script() {
    clear
    print_info "感谢使用 Seren Azuma 系统管理脚本 v$SCRIPT_VERSION"
    print_info "脚本由 $SCRIPT_AUTHOR 开发维护"
    log_message "脚本正常退出" "INFO"
    echo ""
    exit 0
}

# 确认操作
confirm_action() {
    local message=$1
    local default=${2:-N}
    
    if [[ "$default" =~ ^[Yy]$ ]]; then
        print_prompt "$message (Y/n): "
    else
        print_prompt "$message (y/N): "
    fi
    
    read -r response
    
    if [[ -z "$response" ]]; then
        response=$default
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# 验证IP地址格式
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local ip_array=($ip)
        for ((i=0; i<4; i++)); do
            if [[ ${ip_array[i]} -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# 验证端口号
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    fi
    return 1
}

# 生成随机密码
generate_password() {
    local length=${1:-12}
    local charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    else
        for i in $(seq 1 $length); do
            echo -n "${charset:RANDOM%${#charset}:1}"
        done
        echo
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 备份文件
backup_file() {
    local file=$1
    local backup_dir="${2:-$(dirname "$file")}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${backup_dir}/$(basename "$file").bak.${timestamp}"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_name"
        print_success "文件已备份: $backup_name"
        log_message "文件备份: $file -> $backup_name" "INFO"
        return 0
    else
        print_warning "文件不存在，无需备份: $file"
        return 1
    fi
}

# 恢复文件
restore_file() {
    local original_file=$1
    local backup_pattern="${original_file}.bak.*"
    
    # 查找最新的备份文件
    local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        cp "$latest_backup" "$original_file"
        print_success "文件已恢复: $original_file"
        log_message "文件恢复: $latest_backup -> $original_file" "INFO"
        return 0
    else
        print_error "未找到备份文件: $backup_pattern"
        return 1
    fi
}

# 获取系统信息
get_system_info() {
    local info_type=$1
    
    case $info_type in
        "cpu")
            grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
            ;;
        "memory")
            free -h | awk 'NR==2{printf "已用: %s / 总计: %s (%.1f%%)", $3, $2, $3*100/$2}'
            ;;
        "disk")
            df -h / | awk 'NR==2{printf "已用: %s / 总计: %s (%s)", $3, $2, $5}'
            ;;
        "uptime")
            uptime -p 2>/dev/null || uptime | awk '{print $3,$4}' | sed 's/,//'
            ;;
        "load")
            uptime | awk -F'load average:' '{print $2}' | xargs
            ;;
        "ip")
            ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "未知"
            ;;
        "interface")
            ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}' || echo "未知"
            ;;
        *)
            echo "未知信息类型: $info_type"
            return 1
            ;;
    esac
}

# 格式化文件大小
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $size -gt 1024 && $unit -lt 4 ]]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "${size}${units[$unit]}"
}
