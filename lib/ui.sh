#!/bin/bash

# 界面函数库
# 作者: 東雪蓮 (Seren Azuma)

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
    [[ -n "${LOG_FILE:-}" ]] && log_message "INFO: $1" 2>/dev/null || true
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
    [[ -n "${LOG_FILE:-}" ]] && log_message "SUCCESS: $1" 2>/dev/null || true
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
    [[ -n "${LOG_FILE:-}" ]] && log_message "WARNING: $1" 2>/dev/null || true
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
    [[ -n "${LOG_FILE:-}" ]] && log_message "ERROR: $1" 2>/dev/null || true
}

print_header() {
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${BOLD}$1${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 打印分隔线
print_separator() {
    echo -e "${GRAY}─────────────────────────────────────────────────────────────${NC}"
}

# 美化的菜单项显示
print_menu_item() {
    local number=$1
    local description=$2
    printf "  ${CYAN}%2s${NC}. %s\n" "$number" "$description"
}

# 美化的输入提示
print_prompt() {
    local prompt_text=$1
    echo ""
    echo -ne "${BOLD}${BLUE}➤${NC} $prompt_text"
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

# 显示主菜单
show_main_menu() {
    clear
    
    # 检查figlet
    check_figlet
    
    # 显示Seren Azuma艺术字
    if command_exists figlet; then
        echo -e "${BLUE}"
        figlet -w 80 "Seren Azuma" 2>/dev/null || echo "★ Seren Azuma ★"
        echo -e "${NC}"
        echo -e "${CYAN}          通用Linux系统管理脚本 v${SCRIPT_VERSION}${NC}"
    else
        echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║              ${WHITE}★ Seren Azuma ★${BLUE}              ║${NC}"
        echo -e "${BLUE}║        通用Linux系统管理脚本 v${SCRIPT_VERSION}         ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    fi
    
    print_separator
    echo -e "${WHITE}系统: $(get_distro_name) | 包管理器: $PACKAGE_MANAGER | 服务: $SERVICE_MANAGER${NC}"
    print_separator
    
    echo -e "${BOLD}请选择管理类型:${NC}"
    print_menu_item "1" "软件管理"
    print_menu_item "2" "Docker管理"
    print_menu_item "3" "系统管理"
    print_menu_item "4" "安全管理"
    print_menu_item "5" "网络管理"
    print_menu_item "6" "节点搭建"
    print_menu_item "9" "查看日志"
    print_menu_item "0" "退出"
    
    print_prompt "请选择管理类型 [0-6,9]: "
}

# 显示系统信息概览
show_system_info() {
    clear
    print_header "系统信息概览"
    
    echo -e "${CYAN}◆ 操作系统${NC}"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "  名称: $PRETTY_NAME"
        echo "  版本: $VERSION"
        echo "  ID: $(echo ${ID^})"
    fi
    
    print_separator
    echo -e "${CYAN}◆ 硬件信息${NC}"
    echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  核心数: $(nproc)"
    echo "  内存: $(free -h | awk 'NR==2{printf "已用: %s / 总计: %s (%.1f%%)", $3, $2, $3*100/$2}')"
    echo "  磁盘: $(df -h / | awk 'NR==2{printf "已用: %s / 总计: %s (%s)", $3, $2, $5}')"
    
    print_separator
    echo -e "${CYAN}◆ 网络信息${NC}"
    if command_exists ip; then
        local primary_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}')
        local primary_interface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
        echo "  主要网卡: $primary_interface"
        echo "  IP地址: $primary_ip"
    fi
    
    print_separator
    echo -e "${CYAN}◆ 系统状态${NC}"
    echo "  运行时间: $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}' | sed 's/,//')"
    echo "  负载平均: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    echo "  活跃进程: $(ps aux | wc -l)"
    
    print_separator
    echo -e "${CYAN}◆ 服务状态${NC}"
    if [[ $SERVICE_MANAGER == "systemd" ]]; then
        echo "  SSH: $(systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || echo "未知")"
        echo "  UFW防火墙: $(systemctl is-active ufw 2>/dev/null || echo "未安装/未启用")"
        echo "  Docker: $(systemctl is-active docker 2>/dev/null || echo "未安装")"
        if command_exists fail2ban-client; then
            echo "  Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo "未启动")"
        fi
    fi
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r${BLUE}["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%% (%d/%d)${NC}" "$percentage" "$current" "$total"
}

# 选择列表
select_from_list() {
    local title="$1"
    shift
    local items=("$@")
    
    echo -e "${BOLD}$title${NC}"
    print_separator
    
    for i in "${!items[@]}"; do
        print_menu_item "$((i+1))" "${items[$i]}"
    done
    print_menu_item "0" "返回"
    
    while true; do
        print_prompt "请选择 [0-${#items[@]}]: "
        read -r choice
        
        if [[ "$choice" == "0" ]]; then
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#items[@]}" ]]; then
            return "$choice"
        else
            print_error "无效选择，请重新输入"
        fi
    done
}
