#!/bin/bash

# 通用Linux系统管理脚本
# 支持: Ubuntu/Debian, CentOS/RHEL/Rocky/Alma, Fedora, Arch/Manjaro, openSUSE
# 作者: 東雪蓮 (Seren Azuma)
# 版本: 2.3 (优化版)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LOG_FILE="$SCRIPT_DIR/system_manager.log"
DISTRO=""
PACKAGE_MANAGER=""
SERVICE_MANAGER=""
FIREWALL_CMD=""

# 日志记录函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
    log_message "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
    log_message "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
    log_message "WARNING: $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
    log_message "ERROR: $1"
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

# 系统检测
detect_system() {
    print_info "检测系统信息..."
    
    # 检测发行版
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    else
        print_error "无法检测系统类型"
        exit 1
    fi
    
    # 设置包管理器
    case $DISTRO in
        ubuntu|debian|mint|pop)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|rocky|almalinux|ol)
            PACKAGE_MANAGER="yum"
            if command -v dnf >/dev/null 2>&1; then
                PACKAGE_MANAGER="dnf"
            fi
            ;;
        fedora)
            PACKAGE_MANAGER="dnf"
            ;;
        arch|manjaro|garuda|endeavouros)
            PACKAGE_MANAGER="pacman"
            ;;
        opensuse*|sles)
            PACKAGE_MANAGER="zypper"
            ;;
        alpine)
            PACKAGE_MANAGER="apk"
            ;;
        *)
            print_warning "未知的Linux发行版: $DISTRO，尝试自动检测包管理器..."
            if command -v apt >/dev/null 2>&1; then
                PACKAGE_MANAGER="apt"
            elif command -v dnf >/dev/null 2>&1; then
                PACKAGE_MANAGER="dnf"
            elif command -v yum >/dev/null 2>&1; then
                PACKAGE_MANAGER="yum"
            elif command -v pacman >/dev/null 2>&1; then
                PACKAGE_MANAGER="pacman"
            elif command -v zypper >/dev/null 2>&1; then
                PACKAGE_MANAGER="zypper"
            elif command -v apk >/dev/null 2>&1; then
                PACKAGE_MANAGER="apk"
            else
                print_error "无法检测包管理器"
                exit 1
            fi
            ;;
    esac
    
    # 检测服务管理器
    if command -v systemctl >/dev/null 2>&1; then
        SERVICE_MANAGER="systemd"
    elif command -v service >/dev/null 2>&1; then
        SERVICE_MANAGER="sysvinit"
    else
        SERVICE_MANAGER="unknown"
    fi
    
    # 检测防火墙 - 仅检测UFW
    if command -v ufw >/dev/null 2>&1; then
        FIREWALL_CMD="ufw"
    else
        FIREWALL_CMD="none"
    fi
    
    # 获取详细系统版本信息
    local detailed_distro=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu)
                detailed_distro="Ubuntu $VERSION_ID"
                ;;
            debian)
                detailed_distro="Debian $VERSION_ID"
                ;;
            centos)
                detailed_distro="CentOS $VERSION_ID"
                ;;
            rhel)
                detailed_distro="RHEL $VERSION_ID"
                ;;
            rocky)
                detailed_distro="Rocky $VERSION_ID"
                ;;
            almalinux)
                detailed_distro="AlmaLinux $VERSION_ID"
                ;;
            fedora)
                detailed_distro="Fedora $VERSION_ID"
                ;;
            arch)
                detailed_distro="Arch Linux"
                ;;
            manjaro)
                detailed_distro="Manjaro"
                ;;
            opensuse*)
                detailed_distro="openSUSE $VERSION_ID"
                ;;
            alpine)
                detailed_distro="Alpine $VERSION_ID"
                ;;
            *)
                detailed_distro="$PRETTY_NAME"
                ;;
        esac
    else
        detailed_distro=$(echo ${DISTRO^})
    fi
    
    print_success "系统检测完成: $detailed_distro ($PACKAGE_MANAGER, $SERVICE_MANAGER, $FIREWALL_CMD)"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行，请使用 sudo 执行"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    print_info "检查网络连接..."
    local test_hosts=("8.8.8.8" "1.1.1.1" "114.114.114.114")
    local network_ok=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            network_ok=true
            break
        fi
    done
    
    if [[ "$network_ok" == "true" ]]; then
        print_success "网络连接正常"
        return 0
    else
        print_error "网络连接失败，请检查网络设置"
        return 1
    fi
}

# 通用包管理器操作
package_update() {
    print_info "更新软件包列表..."
    case $PACKAGE_MANAGER in
        apt)
            apt update
            ;;
        yum|dnf)
            $PACKAGE_MANAGER check-update || true
            ;;
        pacman)
            pacman -Sy
            ;;
        zypper)
            zypper refresh
            ;;
        apk)
            apk update
            ;;
    esac
}

package_upgrade() {
    print_info "升级系统软件包..."
    case $PACKAGE_MANAGER in
        apt)
            apt upgrade -y
            ;;
        yum|dnf)
            $PACKAGE_MANAGER upgrade -y
            ;;
        pacman)
            pacman -Syu --noconfirm
            ;;
        zypper)
            zypper update -y
            ;;
        apk)
            apk upgrade
            ;;
    esac
}

package_install() {
    local packages=("$@")
    print_info "安装软件包: ${packages[*]}"
    
    case $PACKAGE_MANAGER in
        apt)
            apt install -y "${packages[@]}"
            ;;
        yum|dnf)
            $PACKAGE_MANAGER install -y "${packages[@]}"
            ;;
        pacman)
            pacman -S --noconfirm "${packages[@]}"
            ;;
        zypper)
            zypper install -y "${packages[@]}"
            ;;
        apk)
            apk add "${packages[@]}"
            ;;
    esac
}

# 通用服务管理
service_start() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd)
            systemctl start "$service"
            ;;
        sysvinit)
            service "$service" start
            ;;
    esac
}

service_enable() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd)
            systemctl enable "$service"
            ;;
        sysvinit)
            chkconfig "$service" on 2>/dev/null || update-rc.d "$service" enable 2>/dev/null
            ;;
    esac
}

service_restart() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd)
            systemctl restart "$service"
            ;;
        sysvinit)
            service "$service" restart
            ;;
    esac
}

service_status() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd)
            systemctl status "$service" --no-pager -l
            ;;
        sysvinit)
            service "$service" status
            ;;
    esac
}

# 系统更新
system_update() {
    print_header "开始系统更新"
    
    if package_update; then
        print_success "软件包列表更新完成"
    else
        print_error "软件包列表更新失败"
        return 1
    fi
    
    if package_upgrade; then
        print_success "系统升级完成"
    else
        print_error "系统升级失败"
        return 1
    fi
}

# 安装常用软件
install_common_tools() {
    print_header "安装常用工具软件"
    
    # 根据不同系统定义工具包
    local basic_tools=()
    local network_tools=()
    local dev_tools=()
    
    case $PACKAGE_MANAGER in
        apt)
            basic_tools=("curl" "wget" "unzip" "zip" "vim" "nano" "htop" "tree" "git" "figlet")
            network_tools=("net-tools" "dnsutils" "traceroute" "nmap")
            dev_tools=("build-essential" "software-properties-common")
            ;;
        yum|dnf)
            basic_tools=("curl" "wget" "unzip" "zip" "vim" "nano" "htop" "tree" "git" "figlet")
            network_tools=("net-tools" "bind-utils" "traceroute" "nmap")
            dev_tools=("gcc" "gcc-c++" "make" "kernel-devel")
            ;;
        pacman)
            basic_tools=("curl" "wget" "unzip" "zip" "vim" "nano" "htop" "tree" "git" "figlet")
            network_tools=("net-tools" "bind-tools" "traceroute" "nmap")
            dev_tools=("base-devel")
            ;;
        zypper)
            basic_tools=("curl" "wget" "unzip" "zip" "vim" "nano" "htop" "tree" "git" "figlet")
            network_tools=("net-tools" "bind-utils" "traceroute" "nmap")
            dev_tools=("gcc" "gcc-c++" "make" "kernel-default-devel")
            ;;
        apk)
            basic_tools=("curl" "wget" "unzip" "zip" "vim" "nano" "htop" "tree" "git" "figlet")
            network_tools=("net-tools" "bind-tools" "traceroute" "nmap")
            dev_tools=("build-base" "linux-headers")
            ;;
    esac
    
    # 安装基础工具
    print_info "安装基础工具..."
    if package_install "${basic_tools[@]}"; then
        print_success "基础工具安装完成"
    else
        print_warning "部分基础工具安装失败"
    fi
    
    # 安装网络工具
    print_info "安装网络工具..."
    if package_install "${network_tools[@]}"; then
        print_success "网络工具安装完成"
    else
        print_warning "部分网络工具安装失败"
    fi
    
    # 询问是否安装开发工具
    print_prompt "是否安装开发工具包？(y/N): "
    read -r install_dev
    if [[ "$install_dev" =~ ^[Yy]$ ]]; then
        print_info "安装开发工具..."
        if package_install "${dev_tools[@]}"; then
            print_success "开发工具安装完成"
        else
            print_warning "部分开发工具安装失败"
        fi
    fi
}

# 系统信息显示
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
    if command -v ip >/dev/null 2>&1; then
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
        if command -v fail2ban-client >/dev/null 2>&1; then
            echo "  Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo "未启动")"
        fi
    fi
}

# Docker安装 - 通用版本
install_docker() {
    print_header "安装Docker"
    
    # 检查Docker是否已安装
    if command -v docker >/dev/null 2>&1; then
        print_warning "Docker已经安装"
        docker --version
        return 0
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            # Ubuntu/Debian Docker安装
            print_info "卸载旧版本Docker..."
            apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            print_info "安装依赖包..."
            package_install apt-transport-https ca-certificates gnupg lsb-release
            
            print_info "添加Docker官方GPG密钥..."
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            print_info "添加Docker APT仓库..."
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            package_update
            package_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        yum|dnf)
            # CentOS/RHEL/Fedora Docker安装
            print_info "安装Docker..."
            package_install yum-utils
            
            case $DISTRO in
                centos|rhel|rocky|almalinux)
                    $PACKAGE_MANAGER config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    ;;
                fedora)
                    $PACKAGE_MANAGER config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                    ;;
            esac
            
            package_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        pacman)
            # Arch Linux Docker安装
            package_install docker docker-compose
            ;;
        zypper)
            # openSUSE Docker安装
            package_install docker docker-compose
            ;;
        apk)
            # Alpine Linux Docker安装
            package_install docker docker-compose
            ;;
    esac
    
    # 启动和启用Docker服务
    print_info "启动Docker服务..."
    service_start docker
    service_enable docker
    
    # 将用户添加到docker组
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        print_success "用户 $SUDO_USER 已添加到docker组"
        print_warning "请注销并重新登录以使组权限生效"
    fi
    
    print_success "Docker安装完成"
    docker --version
}

# SSH管理
manage_ssh() {
    while true; do
        clear
        print_header "SSH管理"
        
        # 显示当前SSH状态
        local ssh_service="sshd"
        if ! systemctl list-unit-files | grep -q "^sshd.service"; then
            ssh_service="ssh"
        fi
        
        echo -e "${CYAN}◆ 当前SSH状态${NC}"
        if [[ $SERVICE_MANAGER == "systemd" ]]; then
            echo "  服务状态: $(systemctl is-active $ssh_service 2>/dev/null || echo "未知")"
        fi
        
        local current_port=$(grep "^Port\|^#Port" /etc/ssh/sshd_config 2>/dev/null | head -1)
        if [[ -z "$current_port" ]]; then
            echo "  端口: 22 (默认)"
        else
            echo "  $current_port"
        fi
        
        # 显示Fail2ban状态
        if command -v fail2ban-client >/dev/null 2>&1; then
            echo "  Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo "未知")"
        else
            echo "  Fail2ban: 未安装"
        fi
        
        print_separator
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看SSH日志"
        print_menu_item "2" "重启SSH服务"
        print_menu_item "3" "安装Fail2ban"
        print_menu_item "4" "配置Fail2ban"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-4]: "
        read -r choice
        
        case $choice in
            1) view_ssh_logs ;;
            2) restart_ssh_service ;;
            3) install_fail2ban ;;
            4) configure_fail2ban ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 安装Fail2ban
install_fail2ban() {
    print_header "安装Fail2ban"
    
    if command -v fail2ban-client >/dev/null 2>&1; then
        print_warning "Fail2ban已经安装"
        return 0
    fi
    
    print_info "安装Fail2ban..."
    if package_install fail2ban; then
        service_start fail2ban
        service_enable fail2ban
        print_success "Fail2ban安装并启动成功"
    else
        print_error "Fail2ban安装失败"
        return 1
    fi
}

# 配置Fail2ban
configure_fail2ban() {
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        print_error "Fail2ban未安装，请先安装"
        return 1
    fi
    
    print_header "配置Fail2ban"
    
    # 显示当前状态
    print_info "当前Fail2ban状态:"
    fail2ban-client status 2>/dev/null || print_warning "Fail2ban服务未运行"
    
    echo ""
    echo "请选择配置选项:"
    print_menu_item "1" "启用SSH保护"
    print_menu_item "2" "查看被封IP"
    print_menu_item "3" "解封指定IP"
    print_menu_item "4" "查看Fail2ban日志"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-4]: "
    read -r choice
    
    case $choice in
        1)
            print_info "启用SSH保护..."
            # 创建基本配置
            cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
            service_restart fail2ban
            print_success "SSH保护已启用"
            ;;
        2)
            fail2ban-client status sshd 2>/dev/null || print_warning "SSH jail未配置或未激活"
            ;;
        3)
            print_prompt "请输入要解封的IP地址: "
            read -r ip_to_unban
            if [[ -n "$ip_to_unban" ]]; then
                fail2ban-client set sshd unbanip "$ip_to_unban" && print_success "IP $ip_to_unban 已解封"
            fi
            ;;
        4)
            tail -20 /var/log/fail2ban.log 2>/dev/null || print_warning "无法找到Fail2ban日志"
            ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 系统清理
system_cleanup() {
    print_header "系统清理"
    
    print_info "清理包管理器缓存..."
    case $PACKAGE_MANAGER in
        apt)
            apt autoremove -y
            apt autoclean
            ;;
        yum)
            yum autoremove -y
            yum clean all
            ;;
        dnf)
            dnf autoremove -y
            dnf clean all
            ;;
        pacman)
            pacman -Rns "$(pacman -Qtdq)" 2>/dev/null || true
            pacman -Scc --noconfirm
            ;;
        zypper)
            zypper packages --unneeded | awk -F'|' 'NR==0; NR>2 { print $3 }' | grep -v Name | xargs -r zypper remove -y
            zypper clean
            ;;
        apk)
            apk cache clean
            ;;
    esac
    
    print_info "清理临时文件..."
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    print_info "清理日志文件..."
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --vacuum-time=30d
    fi
    
    # 清理旧的内核（仅Debian/Ubuntu）
    if [[ $PACKAGE_MANAGER == "apt" ]]; then
        print_info "清理旧内核..."
        apt autoremove --purge -y
    fi
    
    print_success "系统清理完成"
    
    # 显示清理后的磁盘使用情况
    echo ""
    echo -e "${CYAN}◆ 当前磁盘使用情况${NC}"
    df -h /
}

# 节点搭建菜单
node_deployment_menu() {
    while true; do
        clear
        print_header "节点搭建"
        
        echo -e "${WHITE}注意: 节点搭建需要网络连接，请确保服务器可以访问外网${NC}"
        
        print_separator
        echo -e "${BOLD}请选择要搭建的节点:${NC}"
        print_menu_item "1" "Snell 代理节点"
        print_menu_item "2" "3X-UI 面板"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择要搭建的节点 [0-2]: "
        read -r choice
        
        case $choice in
            1)
                deploy_snell_node
                ;;
            2)
                deploy_3xui_panel
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选择，请输入0-2之间的数字"
                ;;
        esac
        
        wait_for_key $choice
    done
}

# 部署Snell节点
deploy_snell_node() {
    clear
    print_header "Snell 代理节点部署"
    
    print_info "Snell是一个轻量级的代理工具，支持Surge等客户端"
    
    # 检查网络连接
    if ! check_network; then
        print_error "网络连接失败，无法下载Snell脚本"
        return 1
    fi
    
    print_prompt "确定要开始部署Snell节点吗？(y/N): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消部署"
        return 0
    fi
    
    print_info "下载并执行Snell一键安装脚本..."
    print_warning "脚本将自动配置Snell服务，请按照提示操作"
    
    # 下载并执行Snell脚本
    if wget -O snell.sh --no-check-certificate https://git.io/Snell.sh; then
        chmod +x snell.sh
        print_success "Snell脚本下载成功，开始执行..."
        echo ""
        ./snell.sh
    else
        print_error "Snell脚本下载失败，请检查网络连接"
        return 1
    fi
    
    # 部署完成后的提示
    echo ""
    print_success "Snell节点部署完成！"
    print_info "配置文件通常位于: /etc/snell/snell-server.conf"
    print_info "服务管理命令: systemctl {start|stop|restart|status} snell"
    
    # 检查服务状态
    if systemctl is-active snell >/dev/null 2>&1; then
        print_success "Snell服务运行正常"
        local snell_port=$(grep "listen" /etc/snell/snell-server.conf 2>/dev/null | awk -F':' '{print $2}' | tr -d ' ')
        if [[ -n "$snell_port" ]]; then
            print_info "Snell端口: $snell_port"
        fi
    else
        print_warning "请检查Snell服务状态: systemctl status snell"
    fi
}

# 部署3X-UI面板
deploy_3xui_panel() {
    clear
    print_header "3X-UI 面板管理"
    
    # 检查3X-UI是否已安装
    if command -v x-ui >/dev/null 2>&1 && systemctl list-unit-files | grep -q "x-ui.service"; then
        print_success "检测到3X-UI已安装"
        
        # 显示服务状态
        if systemctl is-active x-ui >/dev/null 2>&1; then
            print_success "3X-UI服务运行正常"
        else
            print_warning "3X-UI服务未运行，正在启动..."
            systemctl start x-ui
            if systemctl is-active x-ui >/dev/null 2>&1; then
                print_success "3X-UI服务启动成功"
            else
                print_error "3X-UI服务启动失败"
                return 1
            fi
        fi
        
        # 检查并启动xray
        check_and_start_xray
        
        # 直接进入管理界面
        print_info "正在启动3X-UI管理界面..."
        x-ui
        return 0
    fi
    
    # 如果未安装，询问是否安装
    print_info "3X-UI是一个强大的代理面板，支持多种协议"
    print_warning "未检测到3X-UI安装"
    
    # 检查网络连接
    if ! check_network; then
        print_error "网络连接失败，无法下载3X-UI脚本"
        return 1
    fi
    
    print_prompt "是否要安装3X-UI面板？(y/N): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消安装"
        return 0
    fi
    
    print_info "下载并执行3X-UI一键安装脚本..."
    print_warning "脚本将自动安装并配置3X-UI面板，请按照提示操作"
    
    echo ""
    # 执行3X-UI安装脚本，让官方脚本直接输出信息
    if bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh); then
        print_success "3X-UI安装完成"
        
        # 检查并启动xray
        check_and_start_xray
        
        # 安装完成后提示进入管理界面
        echo ""
        echo -ne "${CYAN}按回车键进入3X-UI管理面板...${NC}"
        read -r
        
        if command -v x-ui >/dev/null 2>&1; then
            print_info "正在启动3X-UI管理界面..."
            x-ui
        else
            print_warning "x-ui命令未找到，可能需要重新登录或手动执行: x-ui"
        fi
    else
        print_error "3X-UI脚本执行失败，请检查网络连接"
        return 1
    fi
}

# 检查并启动xray服务
check_and_start_xray() {
    # 检查xray是否运行
    if pgrep -f "xray" >/dev/null 2>&1; then
        print_success "Xray服务运行正常"
        return 0
    fi
    
    print_warning "检测到Xray服务未运行，正在尝试启动..."
    
    # 检查systemd服务
    if systemctl list-unit-files | grep -q "xray.service"; then
        if systemctl start xray 2>/dev/null; then
            systemctl enable xray 2>/dev/null
            sleep 2
            if pgrep -f "xray" >/dev/null 2>&1; then
                print_success "Xray服务启动成功"
                return 0
            fi
        fi
    fi
    
    # 再次检查
    sleep 1
    if pgrep -f "xray" >/dev/null 2>&1; then
        print_success "Xray服务已启动"
    else
        print_warning "Xray服务可能需要在管理面板中手动启动"
        print_info "提示: 进入管理面板后，请检查并启动Xray服务"
    fi
}

# 菜单函数
software_management_menu() {
    while true; do
        clear
        print_header "软件管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "系统更新"
        print_menu_item "2" "安装常用工具"
        print_menu_item "3" "系统清理"
        print_menu_item "4" "显示已安装软件"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-4]: "
        read -r choice
        
        case $choice in
            1)
                echo ""
                check_network && system_update
                ;;
            2)
                echo ""
                install_common_tools
                ;;
            3)
                echo ""
                system_cleanup
                ;;
            4)
                echo ""
                show_installed_packages
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选择，请输入0-4之间的数字"
                ;;
        esac
        
        wait_for_key $choice
    done
}

docker_management_menu() {
    while true; do
        clear
        print_header "Docker管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "安装Docker"
        print_menu_item "2" "卸载Docker"
        print_menu_item "3" "查看Docker状态"
        print_menu_item "4" "Docker容器管理"
        print_menu_item "5" "Docker镜像管理"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1)
                echo ""
                check_network && install_docker
                ;;
            2)
                echo ""
                uninstall_docker
                ;;
            3)
                echo ""
                show_docker_status
                ;;
            4)
                echo ""
                docker_container_menu
                ;;
            5)
                echo ""
                docker_image_menu
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选择，请输入0-5之间的数字"
                ;;
        esac
        
        wait_for_key $choice
    done
}

system_management_menu() {
    while true; do
        clear
        print_header "系统管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "SSH管理"
        print_menu_item "2" "更改系统密码"
        print_menu_item "3" "DNS配置"
        print_menu_item "4" "时区设置"
        print_menu_item "5" "UFW防火墙管理"
        print_menu_item "6" "系统工具"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1)
                manage_ssh
                ;;
            2)
                echo ""
                change_system_password
                ;;
            3)
                setup_dns
                ;;
            4)
                setup_timezone
                ;;
            5)
                manage_firewall
                ;;
            6)
                system_tools_menu
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选择，请输入0-6之间的数字"
                ;;
        esac
        
        if [[ $choice != 1 && $choice != 6 && $choice != 0 ]]; then
            wait_for_key $choice
        fi
    done
}

# 系统工具菜单
system_tools_menu() {
    while true; do
        clear
        print_header "系统工具"
        
        echo -e "${BOLD}请选择工具:${NC}"
        print_menu_item "1" "系统信息概览"
        print_menu_item "2" "进程管理"
        print_menu_item "3" "磁盘管理"
        print_menu_item "4" "网络诊断"
        print_menu_item "5" "内存分析"
        print_menu_item "6" "服务管理"
        print_menu_item "7" "用户管理"
        print_menu_item "8" "定时任务管理"
        print_menu_item "0" "返回"
        
        print_prompt "请选择工具 [0-8]: "
        read -r choice
        
        case $choice in
            1) show_system_info ;;
            2) process_management ;;
            3) disk_management ;;
            4) network_diagnostics ;;
            5) memory_analysis ;;
            6) service_management ;;
            7) user_management ;;
            8) cron_management ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 进程管理
process_management() {
    while true; do
        clear
        print_header "进程管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有进程"
        print_menu_item "2" "查看CPU占用最高的进程"
        print_menu_item "3" "查看内存占用最高的进程"
        print_menu_item "4" "杀死进程"
        print_menu_item "5" "查找进程"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1) ps aux | head -20 ;;
            2) ps aux --sort=-%cpu | head -10 ;;
            3) ps aux --sort=-%mem | head -10 ;;
            4) 
                print_prompt "请输入进程PID: "
                read -r pid
                if [[ "$pid" =~ ^[0-9]+$ ]]; then
                    kill "$pid" && print_success "进程 $pid 已终止" || print_error "终止进程失败"
                else
                    print_error "无效的PID"
                fi
                ;;
            5)
                print_prompt "请输入进程名关键词: "
                read -r keyword
                ps aux | grep "$keyword" | grep -v grep
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 磁盘管理
disk_management() {
    while true; do
        clear
        print_header "磁盘管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看磁盘使用情况"
        print_menu_item "2" "查看目录大小"
        print_menu_item "3" "查找大文件"
        print_menu_item "4" "磁盘IO统计"
        print_menu_item "5" "挂载点信息"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1) df -h ;;
            2) 
                print_prompt "请输入目录路径 [/]: "
                read -r dir_path
                dir_path=${dir_path:-/}
                du -sh "$dir_path"/* 2>/dev/null | sort -hr | head -10
                ;;
            3)
                print_prompt "请输入搜索路径 [/]: "
                read -r search_path
                print_prompt "请输入文件大小 (如 100M, 1G): "
                read -r file_size
                search_path=${search_path:-/}
                find "$search_path" -type f -size +"$file_size" 2>/dev/null | head -10
                ;;
            4) 
                if command -v iostat >/dev/null 2>&1; then
                    iostat -x 1 5
                else
                    print_warning "iostat未安装，请安装sysstat包"
                fi
                ;;
            5) mount | column -t ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 网络诊断
network_diagnostics() {
    while true; do
        clear
        print_header "网络诊断"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "网络连接状态"
        print_menu_item "2" "端口扫描"
        print_menu_item "3" "DNS查询测试"
        print_menu_item "4" "网络延迟测试"
        print_menu_item "5" "网卡状态"
        print_menu_item "6" "路由表"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) 
                if command -v ss >/dev/null 2>&1; then
                    ss -tuln
                else
                    netstat -tuln
                fi
                ;;
            2)
                print_prompt "请输入要扫描的主机: "
                read -r host
                print_prompt "请输入端口范围 (如 80 或 80-443): "
                read -r ports
                if command -v nmap >/dev/null 2>&1; then
                    nmap -p "$ports" "$host"
                else
                    print_warning "nmap未安装，无法进行端口扫描"
                fi
                ;;
            3)
                print_prompt "请输入要查询的域名: "
                read -r domain
                if command -v nslookup >/dev/null 2>&1; then
                    nslookup "$domain"
                elif command -v dig >/dev/null 2>&1; then
                    dig "$domain"
                else
                    print_warning "DNS查询工具未安装"
                fi
                ;;
            4)
                print_prompt "请输入要测试的主机: "
                read -r host
                ping -c 5 "$host"
                ;;
            5) ip addr show ;;
            6) ip route show ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 内存分析
memory_analysis() {
    while true; do
        clear
        print_header "内存分析"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "内存使用情况"
        print_menu_item "2" "内存占用最高的进程"
        print_menu_item "3" "系统缓存信息"
        print_menu_item "4" "交换分区信息"
        print_menu_item "5" "释放内存缓存"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1) 
                free -h
                echo ""
                cat /proc/meminfo | head -20
                ;;
            2) ps aux --sort=-%mem | head -10 ;;
            3) 
                echo "页面缓存:"
                cat /proc/meminfo | grep -E "Cached|Buffers"
                ;;
            4) 
                free -h | grep Swap
                swapon --show 2>/dev/null || echo "无交换分区"
                ;;
            5)
                print_prompt "确定要释放内存缓存吗？(y/N): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    sync && echo 3 > /proc/sys/vm/drop_caches
                    print_success "内存缓存已释放"
                fi
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 服务管理
service_management() {
    while true; do
        clear
        print_header "服务管理"
        
        if [[ $SERVICE_MANAGER != "systemd" ]]; then
            print_warning "当前系统不支持systemd服务管理"
            return 1
        fi
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有服务状态"
        print_menu_item "2" "查看运行中的服务"
        print_menu_item "3" "启动服务"
        print_menu_item "4" "停止服务"
        print_menu_item "5" "重启服务"
        print_menu_item "6" "启用服务自启动"
        print_menu_item "7" "禁用服务自启动"
        print_menu_item "8" "查看服务日志"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-8]: "
        read -r choice
        
        case $choice in
            1) systemctl list-units --type=service | head -20 ;;
            2) systemctl list-units --type=service --state=active ;;
            3)
                print_prompt "请输入服务名: "
                read -r service_name
                systemctl start "$service_name" && print_success "服务 $service_name 已启动"
                ;;
            4)
                print_prompt "请输入服务名: "
                read -r service_name
                systemctl stop "$service_name" && print_success "服务 $service_name 已停止"
                ;;
            5)
                print_prompt "请输入服务名: "
                read -r service_name
                systemctl restart "$service_name" && print_success "服务 $service_name 已重启"
                ;;
            6)
                print_prompt "请输入服务名: "
                read -r service_name
                systemctl enable "$service_name" && print_success "服务 $service_name 已设为自启动"
                ;;
            7)
                print_prompt "请输入服务名: "
                read -r service_name
                systemctl disable "$service_name" && print_success "服务 $service_name 已禁用自启动"
                ;;
            8)
                print_prompt "请输入服务名: "
                read -r service_name
                journalctl -u "$service_name" -n 20 --no-pager
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 用户管理
user_management() {
    while true; do
        clear
        print_header "用户管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有用户"
        print_menu_item "2" "查看当前登录用户"
        print_menu_item "3" "添加用户"
        print_menu_item "4" "删除用户"
        print_menu_item "5" "修改用户组"
        print_menu_item "6" "锁定用户"
        print_menu_item "7" "解锁用户"
        print_menu_item "8" "查看用户详情"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-8]: "
        read -r choice
        
        case $choice in
            1) awk -F: '$3>=1000 || $3==0 {print $1 "\t" $3 "\t" $5}' /etc/passwd ;;
            2) who ;;
            3)
                print_prompt "请输入用户名: "
                read -r username
                print_prompt "是否创建家目录? (Y/n): "
                read -r create_home
                if [[ ! "$create_home" =~ ^[Nn]$ ]]; then
                    useradd -m "$username"
                else
                    useradd "$username"
                fi
                passwd "$username"
                ;;
            4)
                print_prompt "请输入要删除的用户名: "
                read -r username
                print_prompt "是否删除家目录? (y/N): "
                read -r delete_home
                if [[ "$delete_home" =~ ^[Yy]$ ]]; then
                    userdel -r "$username"
                else
                    userdel "$username"
                fi
                ;;
            5)
                print_prompt "请输入用户名: "
                read -r username
                print_prompt "请输入要添加的组: "
                read -r group
                usermod -aG "$group" "$username"
                ;;
            6)
                print_prompt "请输入要锁定的用户名: "
                read -r username
                usermod -L "$username" && print_success "用户 $username 已锁定"
                ;;
            7)
                print_prompt "请输入要解锁的用户名: "
                read -r username
                usermod -U "$username" && print_success "用户 $username 已解锁"
                ;;
            8)
                print_prompt "请输入用户名: "
                read -r username
                id "$username" 2>/dev/null || print_error "用户不存在"
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 定时任务管理
cron_management() {
    while true; do
        clear
        print_header "定时任务管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看当前用户的定时任务"
        print_menu_item "2" "编辑当前用户的定时任务"
        print_menu_item "3" "查看系统定时任务"
        print_menu_item "4" "查看定时任务日志"
        print_menu_item "5" "定时任务语法帮助"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1) crontab -l 2>/dev/null || print_info "当前用户没有定时任务" ;;
            2) crontab -e ;;
            3) 
                echo "系统定时任务 (/etc/crontab):"
                cat /etc/crontab 2>/dev/null || print_info "系统定时任务文件不存在"
                echo ""
                echo "其他系统定时任务目录:"
                ls -la /etc/cron.* 2>/dev/null | head -10
                ;;
            4) 
                if command -v journalctl >/dev/null 2>&1; then
                    journalctl -u cron -n 20 --no-pager
                else
                    tail -20 /var/log/cron 2>/dev/null || print_warning "无法找到cron日志"
                fi
                ;;
            5)
                echo "Cron语法格式: 分 时 日 月 周 命令"
                echo ""
                echo "字段说明:"
                echo "  分钟: 0-59"
                echo "  小时: 0-23"
                echo "  日期: 1-31"
                echo "  月份: 1-12"
                echo "  星期: 0-7 (0和7都表示周日)"
                echo ""
                echo "特殊字符:"
                echo "  * : 匹配所有值"
                echo "  , : 分隔多个值"
                echo "  - : 表示范围"
                echo "  / : 表示间隔"
                echo ""
                echo "示例:"
                echo "  0 2 * * * /backup.sh        # 每天2点执行"
                echo "  */5 * * * * /check.sh       # 每5分钟执行"
                echo "  0 0 1 * * /monthly.sh       # 每月1号执行"
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 检查并安装figlet
check_figlet() {
    if ! command -v figlet >/dev/null 2>&1; then
        # 静默安装figlet以获得更好的显示效果
        case $PACKAGE_MANAGER in
            apt|yum|dnf|pacman|zypper|apk)
                package_install figlet >/dev/null 2>&1 || true
                ;;
        esac
    fi
}

# 显示主菜单
show_main_menu() {
    clear
    
    # 检查figlet
    check_figlet
    
    # 显示Seren Azuma艺术字
    if command -v figlet >/dev/null 2>&1; then
        echo -e "${BLUE}"
        figlet -w 80 "Seren Azuma" 2>/dev/null || echo "★ Seren Azuma ★"
        echo -e "${NC}"
        echo -e "${CYAN}          通用Linux系统管理脚本 v2.3${NC}"
    else
        echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║              ${WHITE}★ Seren Azuma ★${BLUE}              ║${NC}"
        echo -e "${BLUE}║        通用Linux系统管理脚本 v2.3         ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    fi
    
    print_separator
    # 获取详细系统版本信息
    local detailed_distro=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu)
                detailed_distro="Ubuntu $VERSION_ID"
                ;;
            debian)
                detailed_distro="Debian $VERSION_ID"
                ;;
            centos)
                detailed_distro="CentOS $VERSION_ID"
                ;;
            rhel)
                detailed_distro="RHEL $VERSION_ID"
                ;;
            rocky)
                detailed_distro="Rocky $VERSION_ID"
                ;;
            almalinux)
                detailed_distro="AlmaLinux $VERSION_ID"
                ;;
            fedora)
                detailed_distro="Fedora $VERSION_ID"
                ;;
            arch)
                detailed_distro="Arch Linux"
                ;;
            manjaro)
                detailed_distro="Manjaro"
                ;;
            opensuse*)
                detailed_distro="openSUSE $VERSION_ID"
                ;;
            alpine)
                detailed_distro="Alpine $VERSION_ID"
                ;;
            *)
                detailed_distro="$PRETTY_NAME"
                ;;
        esac
    else
        detailed_distro=$(echo ${DISTRO^})
    fi
    echo -e "${WHITE}系统: $detailed_distro | 包管理器: $PACKAGE_MANAGER | 服务: $SERVICE_MANAGER${NC}"
    print_separator
    
    echo -e "${BOLD}请选择管理类型:${NC}"
    print_menu_item "1" "软件管理"
    print_menu_item "2" "Docker管理"
    print_menu_item "3" "系统管理"
    print_menu_item "4" "节点搭建"
    print_menu_item "9" "查看日志"
    print_menu_item "0" "退出"
    
    print_prompt "请选择管理类型 [0-4,9]: "
}

# 更改系统密码
change_system_password() {
    print_header "系统密码管理"
    
    echo "当前系统用户："
    awk -F: '$3>=1000 && $3<65534 {print "  - " $1}' /etc/passwd
    echo ""
    
    print_prompt "请输入要修改密码的用户名 (留空则修改当前用户): "
    read -r username
    
    if [[ -z "$username" ]]; then
        if [[ -n "$SUDO_USER" ]]; then
            username="$SUDO_USER"
        else
            username="root"
        fi
    fi
    
    # 检查用户是否存在
    if ! id "$username" >/dev/null 2>&1; then
        print_error "用户 $username 不存在"
        return 1
    fi
    
    print_info "正在修改用户 $username 的密码..."
    
    if passwd "$username"; then
        print_success "用户 $username 的密码修改成功"
    else
        print_error "密码修改失败"
        return 1
    fi
}

# DNS设置
setup_dns() {
    print_header "DNS配置管理"
    
    # 显示当前DNS
    print_info "当前DNS配置："
    if [[ -f /etc/systemd/resolved.conf ]]; then
        grep "^DNS\|^#DNS" /etc/systemd/resolved.conf 2>/dev/null | head -3
    fi
    
    if [[ -f /etc/resolv.conf ]]; then
        echo "resolv.conf内容："
        grep "nameserver" /etc/resolv.conf 2>/dev/null || echo "  未找到nameserver配置"
    fi
    
    echo ""
    echo "请选择DNS设置："
    print_menu_item "1" "国内DNS (阿里云/腾讯)"
    print_menu_item "2" "国际DNS (Google/Cloudflare)"
    print_menu_item "3" "自定义DNS"
    print_menu_item "4" "重置为系统默认"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-4]: "
    read -r dns_choice
    
    case $dns_choice in
        1) select_local_dns ;;
        2) select_international_dns ;;
        3) custom_dns_setup ;;
        4) reset_dns ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 选择国内DNS
select_local_dns() {
    echo "请选择国内DNS："
    print_menu_item "1" "阿里云DNS (223.5.5.5, 223.6.6.6)"
    print_menu_item "2" "腾讯DNS (119.29.29.29, 182.254.116.116)"
    print_menu_item "3" "百度DNS (180.76.76.76, 114.114.114.114)"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-3]: "
    read -r choice
    
    case $choice in
        1) set_dns_servers "223.5.5.5,223.6.6.6" ;;
        2) set_dns_servers "119.29.29.29,182.254.116.116" ;;
        3) set_dns_servers "180.76.76.76,114.114.114.114" ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 选择国际DNS
select_international_dns() {
    echo "请选择国际DNS："
    print_menu_item "1" "Google DNS (8.8.8.8, 8.8.4.4)"
    print_menu_item "2" "Cloudflare DNS (1.1.1.1, 1.0.0.1)"
    print_menu_item "3" "OpenDNS (208.67.222.222, 208.67.220.220)"
    print_menu_item "4" "Quad9 DNS (9.9.9.9, 149.112.112.112)"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-4]: "
    read -r choice
    
    case $choice in
        1) set_dns_servers "8.8.8.8,8.8.4.4" ;;
        2) set_dns_servers "1.1.1.1,1.0.0.1" ;;
        3) set_dns_servers "208.67.222.222,208.67.220.220" ;;
        4) set_dns_servers "9.9.9.9,149.112.112.112" ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 设置DNS服务器
set_dns_servers() {
    local dns_pair=$1
    local primary_dns=$(echo "$dns_pair" | cut -d',' -f1)
    local secondary_dns=$(echo "$dns_pair" | cut -d',' -f2)
    
    print_info "设置DNS为: $primary_dns, $secondary_dns"
    
    # 备份配置
    [[ -f /etc/systemd/resolved.conf ]] && cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak.$(date +%Y%m%d_%H%M%S)
    [[ -f /etc/resolv.conf ]] && cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S)
    
    # 配置DNS
    if [[ -f /etc/systemd/resolved.conf ]] && systemctl is-active systemd-resolved >/dev/null 2>&1; then
        # 使用systemd-resolved
        sed -i '/^DNS=/d' /etc/systemd/resolved.conf
        sed -i '/^\[Resolve\]/a DNS='$primary_dns' '$secondary_dns /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
    else
        # 直接修改resolv.conf
        cat > /etc/resolv.conf << EOF
nameserver $primary_dns
nameserver $secondary_dns
EOF
    fi
    
    print_success "DNS设置完成"
}

# 自定义DNS设置
custom_dns_setup() {
    print_prompt "请输入主DNS服务器: "
    read -r primary_dns
    print_prompt "请输入备用DNS服务器: "
    read -r secondary_dns
    
    # 验证IP格式
    if ! [[ $primary_dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "主DNS格式无效"
        return 1
    fi
    if ! [[ $secondary_dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "备用DNS格式无效"
        return 1
    fi
    
    set_dns_servers "$primary_dns,$secondary_dns"
}

# 重置DNS
reset_dns() {
    print_info "重置DNS为系统默认..."
    
    # 恢复备份文件或使用默认配置
    if [[ -f /etc/systemd/resolved.conf.bak.* ]]; then
        cp /etc/systemd/resolved.conf.bak.* /etc/systemd/resolved.conf 2>/dev/null
        systemctl restart systemd-resolved
    elif [[ -f /etc/resolv.conf.bak.* ]]; then
        cp /etc/resolv.conf.bak.* /etc/resolv.conf 2>/dev/null
    else
        # 使用DHCP默认DNS
        if command -v dhclient >/dev/null 2>&1; then
            dhclient -r && dhclient
        elif command -v NetworkManager >/dev/null 2>&1; then
            systemctl restart NetworkManager
        fi
    fi
    
    print_success "DNS已重置为系统默认"
}

# 时区设置
setup_timezone() {
    print_header "时区配置"
    
    print_info "当前时区设置："
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl show --property=Timezone --value
        timedatectl status
    else
        date
        cat /etc/timezone 2>/dev/null || echo "无法读取时区文件"
    fi
    
    echo ""
    echo "常用时区选择："
    print_menu_item "1" "中国标准时间 (Asia/Shanghai)"
    print_menu_item "2" "美国东部时间 (America/New_York)"
    print_menu_item "3" "美国西部时间 (America/Los_Angeles)"
    print_menu_item "4" "欧洲中部时间 (Europe/Berlin)"
    print_menu_item "5" "日本标准时间 (Asia/Tokyo)"
    print_menu_item "6" "协调世界时 (UTC)"
    print_menu_item "7" "自定义时区"
    print_menu_item "8" "查看所有可用时区"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-8]: "
    read -r tz_choice
    
    case $tz_choice in
        1) set_timezone "Asia/Shanghai" "中国标准时间" ;;
        2) set_timezone "America/New_York" "美国东部时间" ;;
        3) set_timezone "America/Los_Angeles" "美国西部时间" ;;
        4) set_timezone "Europe/Berlin" "欧洲中部时间" ;;
        5) set_timezone "Asia/Tokyo" "日本标准时间" ;;
        6) set_timezone "UTC" "协调世界时" ;;
        7) custom_timezone_setup ;;
        8) show_all_timezones ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 设置时区
set_timezone() {
    local timezone=$1
    local tz_name=$2
    
    print_info "设置时区为 $tz_name ($timezone)..."
    
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl set-timezone "$timezone"; then
            print_success "时区设置成功"
        else
            print_error "时区设置失败"
            return 1
        fi
    else
        # 传统方法
        if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
            ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
            echo "$timezone" > /etc/timezone
            print_success "时区设置成功"
        else
            print_error "时区文件不存在: $timezone"
            return 1
        fi
    fi
    
    print_info "当前时间: $(date)"
}

# 自定义时区设置
custom_timezone_setup() {
    print_prompt "请输入时区 (格式如 Asia/Shanghai): "
    read -r custom_timezone
    
    if [[ -z "$custom_timezone" ]]; then
        print_error "时区不能为空"
        return 1
    fi
    
    set_timezone "$custom_timezone" "自定义时区"
}

# 显示所有时区
show_all_timezones() {
    print_info "显示所有可用时区..."
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl list-timezones | more
    else
        find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | sort | more
    fi
    
    echo ""
    print_prompt "请输入要设置的时区: "
    read -r custom_timezone
    if [[ -n "$custom_timezone" ]]; then
        set_timezone "$custom_timezone" "自定义时区"
    fi
}

# UFW状态显示中文化
translate_ufw_status() {
    local status_output="$1"
    
    # 替换英文状态为中文
    status_output=$(echo "$status_output" | sed 's/Status: active/状态: 活跃/g')
    status_output=$(echo "$status_output" | sed 's/Status: inactive/状态: 未激活/g')
    status_output=$(echo "$status_output" | sed 's/Logging: on (low)/日志: 开启 (低级别)/g')
    status_output=$(echo "$status_output" | sed 's/Logging: on (medium)/日志: 开启 (中级别)/g')
    status_output=$(echo "$status_output" | sed 's/Logging: on (high)/日志: 开启 (高级别)/g')
    status_output=$(echo "$status_output" | sed 's/Logging: on (full)/日志: 开启 (完整)/g')
    status_output=$(echo "$status_output" | sed 's/Logging: off/日志: 关闭/g')
    status_output=$(echo "$status_output" | sed 's/Default: deny (incoming), allow (outgoing), deny (routed)/默认策略: 拒绝入站, 允许出站, 拒绝转发/g')
    status_output=$(echo "$status_output" | sed 's/Default: allow (incoming), allow (outgoing), disabled (routed)/默认策略: 允许入站, 允许出站, 禁用转发/g')
    status_output=$(echo "$status_output" | sed 's/Default: deny (incoming), deny (outgoing), disabled (routed)/默认策略: 拒绝入站, 拒绝出站, 禁用转发/g')
    status_output=$(echo "$status_output" | sed 's/New profiles: skip/新配置: 跳过/g')
    status_output=$(echo "$status_output" | sed 's/To                         Action      From/目标                       动作        来源/g')
    status_output=$(echo "$status_output" | sed 's/--                         ------      ----/--                         ------      ----/g')
    status_output=$(echo "$status_output" | sed 's/ALLOW/允许/g')
    status_output=$(echo "$status_output" | sed 's/DENY/拒绝/g')
    status_output=$(echo "$status_output" | sed 's/REJECT/拒绝/g')
    status_output=$(echo "$status_output" | sed 's/Anywhere/任何地址/g')
    
    echo "$status_output"
}

# UFW命令中文化执行
ufw_chinese() {
    local cmd="$1"
    shift
    local args="$@"
    
    # 执行UFW命令并捕获输出
    local output
    case "$cmd" in
        "enable")
            # 预先回答yes以避免交互提示
            output=$(echo "y" | ufw enable 2>&1)
            ;;
        "disable")
            output=$(ufw disable 2>&1)
            ;;
        "reset")
            # 预先回答yes以避免交互提示
            output=$(echo "y" | ufw --force reset 2>&1)
            ;;
        "allow"|"deny")
            output=$(ufw "$cmd" $args 2>&1)
            ;;
        "delete")
            output=$(ufw --force delete $args 2>&1)
            ;;
        *)
            output=$(ufw "$cmd" $args 2>&1)
            ;;
    esac
    
    # 翻译常见的UFW输出信息
    output=$(echo "$output" | sed 's/Command may disrupt existing ssh connections. Proceed with operation (y|n)?/此命令可能会中断现有的SSH连接。是否继续操作？(y|n)/g')
    output=$(echo "$output" | sed 's/Firewall is active and enabled on system startup/防火墙已激活并在系统启动时自动启用/g')
    output=$(echo "$output" | sed 's/Firewall stopped and disabled on system startup/防火墙已停止并在系统启动时禁用/g')
    output=$(echo "$output" | sed 's/Status: active/状态: 活跃/g')
    output=$(echo "$output" | sed 's/Status: inactive/状态: 未激活/g')
    output=$(echo "$output" | sed 's/Rules updated/规则已更新/g')
    output=$(echo "$output" | sed 's/Rules updated (v6)/规则已更新 (IPv6)/g')
    output=$(echo "$output" | sed 's/Rule added/规则已添加/g')
    output=$(echo "$output" | sed 's/Rule added (v6)/规则已添加 (IPv6)/g')
    output=$(echo "$output" | sed 's/Rule deleted/规则已删除/g')
    output=$(echo "$output" | sed 's/Rule deleted (v6)/规则已删除 (IPv6)/g')
    output=$(echo "$output" | sed 's/Rule updated/规则已更新/g')
    output=$(echo "$output" | sed 's/Rule updated (v6)/规则已更新 (IPv6)/g')
    output=$(echo "$output" | sed 's/Resetting all rules to installed defaults. Proceed with operation (y|n)?/重置所有规则为安装默认值。是否继续操作？(y|n)/g')
    output=$(echo "$output" | sed 's/Backing up/正在备份/g')
    output=$(echo "$output" | sed 's/Proceed with operation (y|n)?/是否继续操作？(y|n)/g')
    output=$(echo "$output" | sed 's/Firewall not enabled (skipping reload)/防火墙未启用 (跳过重新加载)/g')
    output=$(echo "$output" | sed 's/ERROR: Could not find rule/错误: 找不到规则/g')
    output=$(echo "$output" | sed 's/ERROR: Bad port/错误: 端口无效/g')
    output=$(echo "$output" | sed 's/ERROR:/错误:/g')
    output=$(echo "$output" | sed 's/WARNING:/警告:/g')
    
    echo "$output"
}

# UFW防火墙管理
manage_firewall() {
    clear
    print_header "UFW防火墙管理"
    
    # 检查UFW是否已安装
    if ! command -v ufw >/dev/null 2>&1; then
        print_warning "UFW未安装"
        echo ""
        print_menu_item "1" "安装UFW"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-1]: "
        read -r choice
        
        if [[ "$choice" == "1" ]]; then
            print_info "安装UFW..."
            package_install ufw
            if command -v ufw >/dev/null 2>&1; then
                print_success "UFW安装成功"
            else
                print_error "UFW安装失败"
                return 1
            fi
        else
            return 0
        fi
    fi
    
    while true; do
        clear
        print_header "UFW防火墙管理"
        
        echo -e "${CYAN}◆ UFW防火墙状态${NC}"
        translate_ufw_status "$(ufw status verbose)"
        echo ""
        
        print_separator
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "启用防火墙"
        print_menu_item "2" "禁用防火墙"
        print_menu_item "3" "开放端口"
        print_menu_item "4" "关闭端口"
        print_menu_item "5" "删除规则"
        print_menu_item "6" "查看详细规则"
        print_menu_item "7" "重置防火墙"
        print_menu_item "8" "允许常用服务"
        print_menu_item "9" "配置默认策略"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-9]: "
        read -r choice
        
        case $choice in
            1) 
                ufw_chinese "enable"
                print_success "防火墙已启用"
                ;;
            2) 
                ufw_chinese "disable"
                print_success "防火墙已禁用"
                ;;
            3) 
                print_prompt "请输入端口号: "
                read -r port
                print_prompt "协议 (tcp/udp/both) [tcp]: "
                read -r protocol
                protocol=${protocol:-tcp}
                if [[ "$protocol" == "both" ]]; then
                    ufw_chinese "allow" "$port"
                else
                    ufw_chinese "allow" "$port/$protocol"
                fi
                print_success "端口 $port/$protocol 已开放"
                ;;
            4)
                print_prompt "请输入端口号: "
                read -r port
                print_prompt "协议 (tcp/udp/both) [tcp]: "
                read -r protocol
                protocol=${protocol:-tcp}
                if [[ "$protocol" == "both" ]]; then
                    ufw_chinese "deny" "$port"
                else
                    ufw_chinese "deny" "$port/$protocol"
                fi
                print_success "端口 $port/$protocol 已关闭"
                ;;
            5)
                echo "当前规则:"
                translate_ufw_status "$(ufw status numbered)"
                echo ""
                print_prompt "请输入要删除的规则编号: "
                read -r rule_num
                if [[ "$rule_num" =~ ^[0-9]+$ ]]; then
                    ufw_chinese "delete" "$rule_num"
                    print_success "规则已删除"
                else
                    print_error "无效的规则编号"
                fi
                ;;
            6) 
                translate_ufw_status "$(ufw status numbered)"
                ;;
            7) 
                print_prompt "确定要重置所有防火墙规则吗？(y/N): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    ufw_chinese "reset"
                    print_success "防火墙已重置"
                fi
                ;;
            8)
                configure_common_services
                ;;
            9)
                configure_default_policy
                ;;
            0) 
                return
                ;;
            *)
                print_error "无效选择"
                ;;
        esac
        
        wait_for_key $choice
    done
}

# 配置常用服务
configure_common_services() {
    print_header "配置常用服务端口"
    
    echo "请选择要开放的服务:"
    print_menu_item "1" "SSH (22)"
    print_menu_item "2" "HTTP (80)"
    print_menu_item "3" "HTTPS (443)"
    print_menu_item "4" "FTP (21)"
    print_menu_item "5" "MySQL (3306)"
    print_menu_item "6" "PostgreSQL (5432)"
    print_menu_item "7" "Redis (6379)"
    print_menu_item "8" "MongoDB (27017)"
    print_menu_item "9" "全部常用服务"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-9]: "
    read -r service_choice
    
    case $service_choice in
        1) ufw_chinese "allow" "ssh" ;;
        2) ufw_chinese "allow" "http" ;;
        3) ufw_chinese "allow" "https" ;;
        4) ufw_chinese "allow" "ftp" ;;
        5) ufw_chinese "allow" "3306/tcp" ;;
        6) ufw_chinese "allow" "5432/tcp" ;;
        7) ufw_chinese "allow" "6379/tcp" ;;
        8) ufw_chinese "allow" "27017/tcp" ;;
        9)
            ufw_chinese "allow" "ssh"
            ufw_chinese "allow" "http"
            ufw_chinese "allow" "https"
            print_success "常用Web服务端口已开放"
            ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
    
    [[ $service_choice != 0 && $service_choice != 9 ]] && print_success "服务端口已配置"
}

# 配置默认策略
configure_default_policy() {
    print_header "配置默认策略"
    
    echo "当前默认策略:"
    translate_ufw_status "$(ufw status verbose | grep "Default:")"
    echo ""
    
    print_menu_item "1" "默认拒绝入站，允许出站 (推荐)"
    print_menu_item "2" "默认允许入站，允许出站"
    print_menu_item "3" "默认拒绝所有"
    print_menu_item "0" "返回"
    
    print_prompt "请选择 [0-3]: "
    read -r policy_choice
    
    case $policy_choice in
        1)
            ufw_chinese "default" "deny incoming"
            ufw_chinese "default" "allow outgoing"
            print_success "已设置为默认拒绝入站，允许出站"
            ;;
        2)
            ufw_chinese "default" "allow incoming"
            ufw_chinese "default" "allow outgoing"
            print_warning "已设置为默认允许入站，安全性较低"
            ;;
        3)
            ufw_chinese "default" "deny incoming"
            ufw_chinese "default" "deny outgoing"
            print_warning "已设置为默认拒绝所有，可能影响网络连接"
            ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# 显示已安装软件包
show_installed_packages() {
    print_header "已安装软件包"
    
    case $PACKAGE_MANAGER in
        apt)
            dpkg -l | grep "^ii" | awk '{print $2}' | head -20
            echo ""
            print_info "显示前20个软件包，完整列表使用: dpkg -l"
            ;;
        yum|dnf)
            $PACKAGE_MANAGER list installed | head -20
            ;;
        pacman)
            pacman -Q | head -20
            echo ""
            print_info "显示前20个软件包，完整列表使用: pacman -Q"
            ;;
        zypper)
            zypper search --installed-only | head -20
            ;;
        apk)
            apk info | head -20
            ;;
    esac
}

# 卸载Docker
uninstall_docker() {
    print_header "卸载Docker"
    
    # 检查Docker是否已安装
    if ! command -v docker >/dev/null 2>&1; then
        print_info "Docker未安装，无需卸载"
        return 0
    fi
    
    print_prompt "确定要卸载Docker吗？这将删除所有容器和镜像 (y/N): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消卸载"
        return 0
    fi
    
    print_info "停止Docker服务..."
    systemctl stop docker 2>/dev/null || true
    
    print_info "卸载Docker软件包..."
    case $PACKAGE_MANAGER in
        apt)
            apt purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        yum|dnf)
            $PACKAGE_MANAGER remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        pacman)
            pacman -Rns --noconfirm docker docker-compose
            ;;
        zypper)
            zypper remove -y docker docker-compose
            ;;
        apk)
            apk del docker docker-compose
            ;;
    esac
    
    print_info "删除Docker数据目录..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    
    print_success "Docker卸载完成"
}

# 显示Docker状态
show_docker_status() {
    print_header "Docker状态信息"
    
    if command -v docker >/dev/null 2>&1; then
        echo -e "${CYAN}◆ Docker版本${NC}"
        docker --version
        echo
        
        echo -e "${CYAN}◆ Docker服务状态${NC}"
        service_status docker
        echo
        
        echo -e "${CYAN}◆ 运行中的容器${NC}"
        docker ps 2>/dev/null || print_warning "无法获取容器信息，可能需要启动Docker服务"
        echo
        
        echo -e "${CYAN}◆ 所有容器${NC}"
        docker ps -a 2>/dev/null || true
        echo
        
        echo -e "${CYAN}◆ Docker镜像${NC}"
        docker images 2>/dev/null || true
        echo
        
        echo -e "${CYAN}◆ Docker磁盘使用${NC}"
        docker system df 2>/dev/null || true
    else
        print_error "Docker未安装"
    fi
}

# Docker容器管理
docker_container_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker未安装"
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker容器管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有容器"
        print_menu_item "2" "启动容器"
        print_menu_item "3" "停止容器"
        print_menu_item "4" "重启容器"
        print_menu_item "5" "删除容器"
        print_menu_item "6" "进入容器"
        print_menu_item "7" "查看容器日志"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-7]: "
        read -r choice
        
        case $choice in
            1) docker ps -a ;;
            2) 
                print_prompt "请输入容器名或ID: "
                read -r container
                docker start "$container"
                ;;
            3)
                print_prompt "请输入容器名或ID: "
                read -r container
                docker stop "$container"
                ;;
            4)
                print_prompt "请输入容器名或ID: "
                read -r container
                docker restart "$container"
                ;;
            5)
                print_prompt "请输入容器名或ID: "
                read -r container
                docker rm "$container"
                ;;
            6)
                print_prompt "请输入容器名或ID: "
                read -r container
                docker exec -it "$container" /bin/bash || docker exec -it "$container" /bin/sh
                ;;
            7)
                print_prompt "请输入容器名或ID: "
                read -r container
                docker logs "$container"
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# Docker镜像管理
docker_image_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker未安装"
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker镜像管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有镜像"
        print_menu_item "2" "拉取镜像"
        print_menu_item "3" "删除镜像"
        print_menu_item "4" "清理无用镜像"
        print_menu_item "5" "导出镜像"
        print_menu_item "6" "导入镜像"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) docker images ;;
            2) 
                print_prompt "请输入镜像名 (如 nginx:latest): "
                read -r image
                docker pull "$image"
                ;;
            3)
                print_prompt "请输入镜像名或ID: "
                read -r image
                docker rmi "$image"
                ;;
            4)
                print_info "清理无用镜像..."
                docker image prune -f
                ;;
            5)
                print_prompt "请输入镜像名: "
                read -r image
                print_prompt "请输入导出文件名: "
                read -r filename
                docker save -o "$filename" "$image"
                ;;
            6)
                print_prompt "请输入镜像文件路径: "
                read -r filepath
                docker load -i "$filepath"
                ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# SSH相关函数
view_ssh_logs() {
    print_info "查看SSH日志"
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -u ssh -u sshd -n 20 --no-pager
    elif [[ -f /var/log/auth.log ]]; then
        tail -20 /var/log/auth.log | grep ssh
    elif [[ -f /var/log/secure ]]; then
        tail -20 /var/log/secure | grep ssh
    else
        print_warning "无法找到SSH日志文件"
    fi
}

restart_ssh_service() {
    print_info "重启SSH服务..."
    local ssh_service="sshd"
    if ! systemctl list-unit-files | grep -q "^sshd.service"; then
        ssh_service="ssh"
    fi
    
    if service_restart "$ssh_service"; then
        print_success "SSH服务重启成功"
    else
        print_error "SSH服务重启失败"
        return 1
    fi
}

# 主程序
main() {
    # 初始化
    check_root
    detect_system
    
    # 创建日志文件
    touch "$LOG_FILE"
    log_message "脚本启动 - 系统: $(echo ${DISTRO^}), 包管理器: $PACKAGE_MANAGER"
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                software_management_menu
                ;;
            2)
                docker_management_menu
                ;;
            3)
                system_management_menu
                ;;
            4)
                node_deployment_menu
                ;;
            9)
                echo ""
                print_info "显示最近的操作日志："
                tail -20 "$LOG_FILE"
                wait_for_key 1
                ;;
            0)
                print_info "感谢使用 Seren Azuma 系统管理脚本"
                log_message "脚本退出"
                exit 0
                ;;
            *)
                print_error "无效的选择，请输入0-4或9"
                wait_for_key 1
                ;;
        esac
    done
}

# 运行主程序
main "$@"