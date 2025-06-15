#!/bin/bash

# UI界面函数库
# 包含所有界面显示、菜单、提示等UI相关功能

# ============================================================================
# 基础UI输出函数
# ============================================================================

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
    log_message "INFO: $1" "INFO"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
    log_message "SUCCESS: $1" "INFO"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
    log_message "WARNING: $1" "WARNING"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
    log_message "ERROR: $1" "ERROR"
}

print_debug() {
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        echo -e "${GRAY}[调试]${NC} $1"
        log_message "DEBUG: $1" "DEBUG"
    fi
}

# 打印标题头
print_header() {
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${BOLD}$1${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 打印子标题
print_subheader() {
    echo ""
    echo -e "${CYAN}▶ ${BOLD}$1${NC}"
    echo ""
}

# 打印分隔线
print_separator() {
    echo -e "${GRAY}─────────────────────────────────────────────────────────────${NC}"
}

# 打印双分隔线
print_double_separator() {
    echo -e "${GRAY}═════════════════════════════════════════════════════════════${NC}"
}

# 美化的菜单项显示
print_menu_item() {
    local number=$1
    local description=$2
    local status=${3:-""}
    
    if [[ -n "$status" ]]; then
        printf "  ${CYAN}%2s${NC}. %-30s ${GRAY}[%s]${NC}\n" "$number" "$description" "$status"
    else
        printf "  ${CYAN}%2s${NC}. %s\n" "$number" "$description"
    fi
}

# 美化的输入提示
print_prompt() {
    local prompt_text=$1
    local default_value=${2:-""}
    
    echo ""
    if [[ -n "$default_value" ]]; then
        echo -ne "${BOLD}${BLUE}➤${NC} $prompt_text ${GRAY}[默认: $default_value]${NC}: "
    else
        echo -ne "${BOLD}${BLUE}➤${NC} $prompt_text: "
    fi
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local message=${3:-"处理中"}
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}[信息]${NC} $message: ["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%%" "$percentage"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# 显示加载动画
show_spinner() {
    local pid=$1
    local message=${2:-"处理中"}
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${BLUE}[信息]${NC} $message %s" "${chars:$i:1}"
        i=$(( (i+1) % ${#chars} ))
        sleep 0.1
    done
    printf "\r${GREEN}[完成]${NC} $message ✓\n"
}

# ============================================================================
# 系统信息显示函数
# ============================================================================

# 显示系统概览信息
show_system_overview() {
    clear
    print_header "系统信息概览"
    
    echo -e "${CYAN}◆ 操作系统${NC}"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "  名称: $PRETTY_NAME"
        echo "  版本: ${VERSION:-"未知"}"
        echo "  架构: $(uname -m)"
        echo "  内核: $(uname -r)"
    fi
    
    print_separator
    echo -e "${CYAN}◆ 硬件信息${NC}"
    echo "  CPU: $(get_system_info cpu)"
    echo "  核心数: $(nproc)"
    echo "  内存: $(get_system_info memory)"
    echo "  磁盘: $(get_system_info disk)"
    
    print_separator
    echo -e "${CYAN}◆ 网络信息${NC}"
    local primary_ip=$(get_system_info ip)
    local primary_interface=$(get_system_info interface)
    echo "  主要网卡: $primary_interface"
    echo "  IP地址: $primary_ip"
    
    if command -v ss >/dev/null 2>&1; then
        local listening_ports=$(ss -tuln | grep LISTEN | wc -l)
        echo "  监听端口数: $listening_ports"
    fi
    
    print_separator
    echo -e "${CYAN}◆ 系统状态${NC}"
    echo "  运行时间: $(get_system_info uptime)"
    echo "  负载平均: $(get_system_info load)"
    echo "  活跃进程: $(ps aux | wc -l)"
    echo "  登录用户: $(who | wc -l)"
    
    print_separator
    echo -e "${CYAN}◆ 服务状态${NC}"
    show_service_status_summary
}

# 显示服务状态摘要
show_service_status_summary() {
    if [[ $SERVICE_MANAGER == "systemd" ]]; then
        # SSH服务状态
        local ssh_service="sshd"
        if ! systemctl list-unit-files | grep -q "^sshd.service"; then
            ssh_service="ssh"
        fi
        local ssh_status=$(systemctl is-active $ssh_service 2>/dev/null || echo "未知")
        echo "  SSH: $ssh_status"
        
        # 防火墙状态
        case $FIREWALL_CMD in
            ufw)
                local ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "未知")
                echo "  UFW防火墙: $ufw_status"
                ;;
            firewalld)
                local firewalld_status=$(systemctl is-active firewalld 2>/dev/null || echo "未知")
                echo "  Firewalld: $firewalld_status"
                ;;
            *)
                echo "  防火墙: 未配置"
                ;;
        esac
        
        # Docker状态
        if command -v docker >/dev/null 2>&1; then
            local docker_status=$(systemctl is-active docker 2>/dev/null || echo "未安装")
            echo "  Docker: $docker_status"
        fi
        
        # Fail2ban状态
        if command -v fail2ban-client >/dev/null 2>&1; then
            local fail2ban_status=$(systemctl is-active fail2ban 2>/dev/null || echo "未启动")
            echo "  Fail2ban: $fail2ban_status"
        fi
    else
        echo "  服务管理器: $SERVICE_MANAGER"
    fi
}

# ============================================================================
# 主菜单显示函数
# ============================================================================

# 显示主菜单
show_main_menu() {
    clear
    
    # 显示艺术字标题
    show_logo
    
    # 显示系统信息条
    show_system_info_bar
    
    print_separator
    
    # 显示主菜单选项
    echo -e "${BOLD}请选择管理类型:${NC}"
    print_menu_item "1" "软件管理" "包管理、系统更新"
    print_menu_item "2" "Docker管理" "容器、镜像管理"
    print_menu_item "3" "系统管理" "用户、服务、安全"
    print_menu_item "4" "节点搭建" "代理节点部署"
    print_menu_item "5" "系统工具" "监控、诊断工具"
    print_separator
    print_menu_item "8" "系统信息" "查看详细信息"
    print_menu_item "9" "查看日志" "操作记录"
    print_menu_item "0" "退出程序" "安全退出"
    
    print_prompt "请选择管理类型 [0-9]"
}

# 显示Logo
show_logo() {
    # 检查并安装figlet以获得更好的显示效果
    if command -v figlet >/dev/null 2>&1; then
        echo -e "${BLUE}"
        figlet -w 80 "Seren Azuma" 2>/dev/null || show_simple_logo
        echo -e "${NC}"
        echo -e "${CYAN}          通用Linux系统管理脚本 v${SCRIPT_VERSION} (模块化版本)${NC}"
    else
        show_simple_logo
    fi
}

# 显示简单Logo
show_simple_logo() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              ${WHITE}★ Seren Azuma ★${BLUE}              ║${NC}"
    echo -e "${BLUE}║        通用Linux系统管理脚本 v${SCRIPT_VERSION}         ║${NC}"
    echo -e "${BLUE}║             (模块化版本)                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
}

# 显示系统信息条
show_system_info_bar() {
    local memory_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    local disk_usage=$(df / | awk 'NR==2{print $5}')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
    
    echo -e "${WHITE}系统: $DETAILED_DISTRO │ 内存: $memory_usage │ 磁盘: $disk_usage │ 负载: $load_avg${NC}"
    echo -e "${GRAY}包管理: $PACKAGE_MANAGER │ 服务: $SERVICE_MANAGER │ 防火墙: $FIREWALL_CMD │ 作者: $SCRIPT_AUTHOR${NC}"
}

# ============================================================================
# 交互式界面函数
# ============================================================================

# 显示选择列表
show_selection_list() {
    local title=$1
    shift
    local options=("$@")
    
    clear
    print_header "$title"
    
    for i in "${!options[@]}"; do
        print_menu_item "$((i+1))" "${options[i]}"
    done
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-${#options[@]}]"
}

# 显示确认对话框
show_confirmation_dialog() {
    local message=$1
    local default=${2:-"N"}
    
    echo ""
    echo -e "${YELLOW}⚠️  确认操作${NC}"
    echo -e "${WHITE}$message${NC}"
    echo ""
    
    if [[ "$default" =~ ^[Yy]$ ]]; then
        print_prompt "确定要继续吗？(Y/n)"
        read -r response
        response=${response:-Y}
    else
        print_prompt "确定要继续吗？(y/N)"
        read -r response
        response=${response:-N}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# 显示输入对话框
show_input_dialog() {
    local title=$1
    local prompt=$2
    local default=${3:-""}
    local validation_pattern=${4:-".*"}
    
    while true; do
        echo ""
        echo -e "${CYAN}◆ $title${NC}"
        
        if [[ -n "$default" ]]; then
            print_prompt "$prompt" "$default"
        else
            print_prompt "$prompt"
        fi
        
        read -r user_input
        
        # 如果为空且有默认值，使用默认值
        if [[ -z "$user_input" && -n "$default" ]]; then
            user_input="$default"
        fi
        
        # 验证输入
        if [[ "$user_input" =~ $validation_pattern ]]; then
            echo "$user_input"
            return 0
        else
            print_error "输入格式不正确，请重新输入"
        fi
    done
}

# 显示密码输入对话框
show_password_dialog() {
    local prompt=${1:-"请输入密码"}
    
    echo ""
    echo -ne "${BOLD}${BLUE}➤${NC} $prompt: "
    read -s password
    echo ""
    echo "$password"
}

# 显示多选菜单
show_multi_select_menu() {
    local title=$1
    shift
    local options=("$@")
    local selected=()
    
    while true; do
        clear
        print_header "$title"
        
        echo -e "${CYAN}使用空格键选择/取消选择，回车键确认${NC}"
        echo ""
        
        for i in "${!options[@]}"; do
            local mark=" "
            if [[ " ${selected[*]} " =~ " $i " ]]; then
                mark="✓"
            fi
            printf "  [%s] %2d. %s\n" "$mark" "$((i+1))" "${options[i]}"
        done
        
        print_separator
        print_menu_item "a" "全选"
        print_menu_item "n" "全不选"
        print_menu_item "d" "完成选择"
        print_menu_item "q" "取消"
        
        print_prompt "请选择操作 [数字/a/n/d/q]"
        read -r choice
        
        case $choice in
            [0-9]*)
                local index=$((choice - 1))
                if [[ $index -ge 0 && $index -lt ${#options[@]} ]]; then
                    if [[ " ${selected[*]} " =~ " $index " ]]; then
                        # 移除选择
                        selected=($(printf '%s\n' "${selected[@]}" | grep -v "^$index$"))
                    else
                        # 添加选择
                        selected+=($index)
                    fi
                fi
                ;;
            a|A)
                selected=($(seq 0 $((${#options[@]} - 1))))
                ;;
            n|N)
                selected=()
                ;;
            d|D)
                break
                ;;
            q|Q)
                return 1
                ;;
        esac
    done
    
    # 返回选中的索引
    printf '%s\n' "${selected[@]}"
    return 0
}

# ============================================================================
# 状态显示函数
# ============================================================================

# 显示服务状态
show_service_status() {
    local service=$1
    
    if service_is_active "$service"; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
}

# 显示服务启用状态
show_service_enabled_status() {
    local service=$1
    
    if service_is_enabled "$service"; then
        echo -e "${GREEN}已启用${NC}"
    else
        echo -e "${YELLOW}未启用${NC}"
    fi
}

# 显示在线状态
show_online_status() {
    if check_network >/dev/null 2>&1; then
        echo -e "${GREEN}在线${NC}"
    else
        echo -e "${RED}离线${NC}"
    fi
}

# 显示磁盘使用状态
show_disk_usage_status() {
    local usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    
    if [[ $usage -lt 70 ]]; then
        echo -e "${GREEN}$usage%${NC}"
    elif [[ $usage -lt 90 ]]; then
        echo -e "${YELLOW}$usage%${NC}"
    else
        echo -e "${RED}$usage%${NC}"
    fi
}

# 显示内存使用状态
show_memory_usage_status() {
    local usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ $usage -lt 70 ]]; then
        echo -e "${GREEN}$usage%${NC}"
    elif [[ $usage -lt 90 ]]; then
        echo -e "${YELLOW}$usage%${NC}"
    else
        echo -e "${RED}$usage%${NC}"
    fi
}

# ============================================================================
# 表格显示函数
# ============================================================================

# 显示表格头
show_table_header() {
    local columns=("$@")
    local separator=""
    
    # 打印表头
    printf "│"
    for col in "${columns[@]}"; do
        printf " %-20s │" "$col"
        separator+="├──────────────────────┼"
    done
    echo ""
    
    # 打印分隔线
    echo "${separator%?}┤"
}

# 显示表格行
show_table_row() {
    local values=("$@")
    
    printf "│"
    for val in "${values[@]}"; do
        printf " %-20s │" "$val"
    done
    echo ""
}

# 显示进程表格
show_process_table() {
    local sort_by=${1:-"cpu"}
    
    print_header "进程信息"
    
    case $sort_by in
        cpu)
            echo -e "${CYAN}按CPU使用率排序 (前10个进程)${NC}"
            ps aux --sort=-%cpu | head -11 | awk '
            NR==1 {printf "│ %-8s │ %-8s │ %-8s │ %-8s │ %-20s │\n", "用户", "PID", "CPU%", "内存%", "命令"}
            NR==1 {print "├──────────┼──────────┼──────────┼──────────┼──────────────────────┤"}
            NR>1  {printf "│ %-8s │ %-8s │ %-8s │ %-8s │ %-20s │\n", $1, $2, $3, $4, $11}'
            ;;
        mem)
            echo -e "${CYAN}按内存使用率排序 (前10个进程)${NC}"
            ps aux --sort=-%mem | head -11 | awk '
            NR==1 {printf "│ %-8s │ %-8s │ %-8s │ %-8s │ %-20s │\n", "用户", "PID", "CPU%", "内存%", "命令"}
            NR==1 {print "├──────────┼──────────┼──────────┼──────────┼──────────────────────┤"}
            NR>1  {printf "│ %-8s │ %-8s │ %-8s │ %-8s │ %-20s │\n", $1, $2, $3, $4, $11}'
            ;;
    esac
}

# 显示网络连接表格
show_network_table() {
    print_header "网络连接"
    
    if command -v ss >/dev/null 2>&1; then
        echo -e "${CYAN}当前网络连接${NC}"
        ss -tuln | awk '
        NR==1 {printf "│ %-8s │ %-15s │ %-15s │ %-10s │\n", "协议", "本地地址", "远程地址", "状态"}
        NR==1 {print "├──────────┼─────────────────┼─────────────────┼────────────┤"}
        NR>1  {printf "│ %-8s │ %-15s │ %-15s │ %-10s │\n", $1, $4, $5, $2}'
    else
        echo -e "${CYAN}当前网络连接${NC}"
        netstat -tuln 2>/dev/null | awk '
        /^Proto/ {printf "│ %-8s │ %-15s │ %-15s │ %-10s │\n", "协议", "本地地址", "远程地址", "状态"}
        /^Proto/ {print "├──────────┼─────────────────┼─────────────────┼────────────┤"}
        /^tcp|^udp/ {printf "│ %-8s │ %-15s │ %-15s │ %-10s │\n", $1, $4, $5, $6}'
    fi
}

# ============================================================================
# 错误处理和提示函数
# ============================================================================

# 显示错误详情
show_error_detail() {
    local error_code=$1
    local error_message=$2
    local suggestion=${3:-"请检查系统日志获取更多信息"}
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}║              错误详情                ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}错误代码:${NC} $error_code"
    echo -e "${BOLD}错误信息:${NC} $error_message"
    echo -e "${BOLD}建议操作:${NC} $suggestion"
    echo ""
}

# 显示警告提示
show_warning_box() {
    local title=$1
    local message=$2
    
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              $title                ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}$message${NC}"
    echo ""
}

# 显示成功提示
show_success_box() {
    local title=$1
    local message=$2
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              $title                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}$message${NC}"
    echo ""
}

# 显示帮助信息
show_help() {
    clear
    print_header "帮助信息"
    
    echo -e "${CYAN}◆ 关于此脚本${NC}"
    echo "  Seren Azuma 系统管理脚本是一个通用的Linux系统管理工具"
    echo "  支持主流Linux发行版的软件管理、系统配置、安全加固等功能"
    echo ""
    
    echo -e "${CYAN}◆ 支持的系统${NC}"
    echo "  • Ubuntu/Debian 系列"
    echo "  • CentOS/RHEL/Rocky/Alma 系列"
    echo "  • Fedora"
    echo "  • Arch/Manjaro 系列"
    echo "  • openSUSE 系列"
    echo "  • Alpine Linux"
    echo ""
    
    echo -e "${CYAN}◆ 主要功能${NC}"
    echo "  • 软件包管理和系统更新"
    echo "  • Docker 容器管理"
    echo "  • 系统服务和安全配置"
    echo "  • 网络代理节点部署"
    echo "  • 系统监控和诊断工具"
    echo ""
    
    echo -e "${CYAN}◆ 使用技巧${NC}"
    echo "  • 使用数字键快速选择菜单项"
    echo "  • 按 Ctrl+C 可以随时退出当前操作"
    echo "  • 重要操作会要求确认，请仔细阅读提示"
    echo "  • 所有操作都会记录在日志中"
    echo ""
    
    echo -e "${CYAN}◆ 安全建议${NC}"
    echo "  • 定期更新系统和软件包"
    echo "  • 配置防火墙和入侵检测"
    echo "  • 使用强密码和密钥认证"
    echo "  • 定期备份重要数据"
    echo ""
    
    echo -e "${CYAN}◆ 故障排除${NC}"
    echo "  • 查看日志: 主菜单 -> 9"
    echo "  • 网络问题: 检查DNS和防火墙设置"
    echo "  • 权限问题: 确保使用sudo运行脚本"
    echo "  • 包管理问题: 尝试清理缓存后重试"
    echo ""
    
    echo -e "${CYAN}◆ 联系作者${NC}"
    echo "  作者: $SCRIPT_AUTHOR"
    echo "  版本: $SCRIPT_VERSION"
    echo ""
    
    wait_for_key 1
}

# ============================================================================
# 动画和特效函数
# ============================================================================

# 显示加载动画
show_loading_animation() {
    local message=${1:-"加载中"}
    local duration=${2:-3}
    
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local frame_count=${#frames[@]}
    
    for ((i=0; i<duration*10; i++)); do
        local frame_index=$((i % frame_count))
        printf "\r${BLUE}%s${NC} %s" "${frames[frame_index]}" "$message"
        sleep 0.1
    done
    
    printf "\r${GREEN}✓${NC} %s 完成\n" "$message"
}

# 显示打字机效果
show_typewriter_effect() {
    local text=$1
    local delay=${2:-0.05}
    
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# 显示彩色横幅
show_banner() {
    local text=$1
    local color=${2:-$BLUE}
    
    local length=${#text}
    local border=$(printf "%*s" $((length + 4)) | tr ' ' '=')
    
    echo -e "${color}$border${NC}"
    echo -e "${color}  $text  ${NC}"
    echo -e "${color}$border${NC}"
}

# 清屏并显示标题
clear_and_header() {
    clear
    print_header "$1"
}
