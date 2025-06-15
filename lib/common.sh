#!/bin/bash

# 公共函数库
# 作者: 東雪蓮 (Seren Azuma)

# 日志初始化
init_logging() {
    touch "$LOG_FILE" 2>/dev/null || {
        LOG_FILE="/tmp/system_manager.log"
        touch "$LOG_FILE"
    }
}

# 日志记录函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[错误]${NC} 此脚本需要root权限运行，请使用 sudo 执行"
        exit 1
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
            command -v dnf >/dev/null 2>&1 && PACKAGE_MANAGER="dnf"
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
            auto_detect_package_manager
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
    
    # 检测防火墙
    if command -v ufw >/dev/null 2>&1; then
        FIREWALL_CMD="ufw"
    else
        FIREWALL_CMD="none"
    fi
    
    print_success "系统检测完成: $(get_distro_name) ($PACKAGE_MANAGER, $SERVICE_MANAGER, $FIREWALL_CMD)"
}

# 自动检测包管理器
auto_detect_package_manager() {
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
}

# 获取发行版名称
get_distro_name() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu) echo "Ubuntu $VERSION_ID" ;;
            debian) echo "Debian $VERSION_ID" ;;
            centos) echo "CentOS $VERSION_ID" ;;
            rhel) echo "RHEL $VERSION_ID" ;;
            rocky) echo "Rocky $VERSION_ID" ;;
            almalinux) echo "AlmaLinux $VERSION_ID" ;;
            fedora) echo "Fedora $VERSION_ID" ;;
            arch) echo "Arch Linux" ;;
            manjaro) echo "Manjaro" ;;
            opensuse*) echo "openSUSE $VERSION_ID" ;;
            alpine) echo "Alpine $VERSION_ID" ;;
            *) echo "$PRETTY_NAME" ;;
        esac
    else
        echo "${DISTRO^}"
    fi
}

# 检查网络连接
check_network() {
    print_info "检查网络连接..."
    for host in "${NETWORK_TEST_HOSTS[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            print_success "网络连接正常"
            return 0
        fi
    done
    print_error "网络连接失败，请检查网络设置"
    return 1
}

# 通用包管理器操作
package_update() {
    print_info "更新软件包列表..."
    case $PACKAGE_MANAGER in
        apt) apt update ;;
        yum|dnf) $PACKAGE_MANAGER check-update || true ;;
        pacman) pacman -Sy ;;
        zypper) zypper refresh ;;
        apk) apk update ;;
    esac
}

package_upgrade() {
    print_info "升级系统软件包..."
    case $PACKAGE_MANAGER in
        apt) apt upgrade -y ;;
        yum|dnf) $PACKAGE_MANAGER upgrade -y ;;
        pacman) pacman -Syu --noconfirm ;;
        zypper) zypper update -y ;;
        apk) apk upgrade ;;
    esac
}

package_install() {
    local packages=("$@")
    print_info "安装软件包: ${packages[*]}"
    
    case $PACKAGE_MANAGER in
        apt) apt install -y "${packages[@]}" ;;
        yum|dnf) $PACKAGE_MANAGER install -y "${packages[@]}" ;;
        pacman) pacman -S --noconfirm "${packages[@]}" ;;
        zypper) zypper install -y "${packages[@]}" ;;
        apk) apk add "${packages[@]}" ;;
    esac
}

package_remove() {
    local packages=("$@")
    print_info "卸载软件包: ${packages[*]}"
    
    case $PACKAGE_MANAGER in
        apt) apt purge -y "${packages[@]}" ;;
        yum|dnf) $PACKAGE_MANAGER remove -y "${packages[@]}" ;;
        pacman) pacman -Rns --noconfirm "${packages[@]}" ;;
        zypper) zypper remove -y "${packages[@]}" ;;
        apk) apk del "${packages[@]}" ;;
    esac
}

# 通用服务管理
service_start() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl start "$service" ;;
        sysvinit) service "$service" start ;;
    esac
}

service_stop() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl stop "$service" ;;
        sysvinit) service "$service" stop ;;
    esac
}

service_enable() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl enable "$service" ;;
        sysvinit) chkconfig "$service" on 2>/dev/null || update-rc.d "$service" enable 2>/dev/null ;;
    esac
}

service_disable() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl disable "$service" ;;
        sysvinit) chkconfig "$service" off 2>/dev/null || update-rc.d "$service" disable 2>/dev/null ;;
    esac
}

service_restart() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl restart "$service" ;;
        sysvinit) service "$service" restart ;;
    esac
}

service_status() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl status "$service" --no-pager -l ;;
        sysvinit) service "$service" status ;;
    esac
}

service_is_active() {
    local service=$1
    case $SERVICE_MANAGER in
        systemd) systemctl is-active "$service" >/dev/null 2>&1 ;;
        sysvinit) service "$service" status >/dev/null 2>&1 ;;
    esac
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 确认操作
confirm_action() {
    local prompt="${1:-确定要执行此操作吗？}"
    print_prompt "$prompt (y/N): "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# 检查并安装figlet
check_figlet() {
    if ! command_exists figlet; then
        package_install figlet >/dev/null 2>&1 || true
    fi
}
