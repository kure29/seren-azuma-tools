#!/bin/bash

# 系统检测和基础功能库
# 包含系统检测、包管理、服务管理等基础功能

# 系统检测主函数
detect_system() {
    print_info "检测系统信息..."
    
    # 检测Linux发行版
    detect_distro
    
    # 检测包管理器
    detect_package_manager
    
    # 检测服务管理器
    detect_service_manager
    
    # 检测防火墙
    detect_firewall
    
    # 获取详细系统信息
    get_detailed_system_info
    
    print_success "系统检测完成: $DETAILED_DISTRO ($PACKAGE_MANAGER, $SERVICE_MANAGER, $FIREWALL_CMD)"
    log_message "系统检测完成 - 发行版: $DISTRO, 包管理器: $PACKAGE_MANAGER" "INFO"
}

# 检测Linux发行版
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    elif [[ -f /etc/alpine-release ]]; then
        DISTRO="alpine"
    else
        print_warning "无法检测系统类型，尝试通用检测..."
        DISTRO="unknown"
    fi
}

# 检测包管理器
detect_package_manager() {
    case $DISTRO in
        ubuntu|debian|mint|pop|kali|deepin)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|rocky|almalinux|ol|eurolinux)
            PACKAGE_MANAGER="yum"
            if command -v dnf >/dev/null 2>&1; then
                PACKAGE_MANAGER="dnf"
            fi
            ;;
        fedora|nobara)
            PACKAGE_MANAGER="dnf"
            ;;
        arch|manjaro|garuda|endeavouros|artix|blackarch)
            PACKAGE_MANAGER="pacman"
            ;;
        opensuse*|sles|sled)
            PACKAGE_MANAGER="zypper"
            ;;
        alpine)
            PACKAGE_MANAGER="apk"
            ;;
        void)
            PACKAGE_MANAGER="xbps"
            ;;
        gentoo)
            PACKAGE_MANAGER="emerge"
            ;;
        *)
            auto_detect_package_manager
            ;;
    esac
}

# 自动检测包管理器
auto_detect_package_manager() {
    print_warning "未知的Linux发行版: $DISTRO，尝试自动检测包管理器..."
    
    local managers=("apt" "dnf" "yum" "pacman" "zypper" "apk" "xbps" "emerge")
    
    for manager in "${managers[@]}"; do
        if command -v "$manager" >/dev/null 2>&1; then
            PACKAGE_MANAGER="$manager"
            print_info "检测到包管理器: $manager"
            return 0
        fi
    done
    
    print_error "无法检测包管理器"
    log_message "包管理器检测失败" "ERROR"
    exit 1
}

# 检测服务管理器
detect_service_manager() {
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        SERVICE_MANAGER="systemd"
    elif command -v service >/dev/null 2>&1; then
        SERVICE_MANAGER="sysvinit"
    elif command -v rc-service >/dev/null 2>&1; then
        SERVICE_MANAGER="openrc"
    else
        SERVICE_MANAGER="unknown"
        print_warning "无法检测服务管理器"
    fi
}

# 检测防火墙
detect_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        FIREWALL_CMD="ufw"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        FIREWALL_CMD="firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        FIREWALL_CMD="iptables"
    else
        FIREWALL_CMD="none"
    fi
}

# 获取详细系统信息
get_detailed_system_info() {
    DETAILED_DISTRO=""
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu) DETAILED_DISTRO="Ubuntu $VERSION_ID" ;;
            debian) DETAILED_DISTRO="Debian $VERSION_ID" ;;
            centos) DETAILED_DISTRO="CentOS $VERSION_ID" ;;
            rhel) DETAILED_DISTRO="RHEL $VERSION_ID" ;;
            rocky) DETAILED_DISTRO="Rocky Linux $VERSION_ID" ;;
            almalinux) DETAILED_DISTRO="AlmaLinux $VERSION_ID" ;;
            fedora) DETAILED_DISTRO="Fedora $VERSION_ID" ;;
            arch) DETAILED_DISTRO="Arch Linux" ;;
            manjaro) DETAILED_DISTRO="Manjaro" ;;
            opensuse*) DETAILED_DISTRO="openSUSE $VERSION_ID" ;;
            alpine) DETAILED_DISTRO="Alpine $VERSION_ID" ;;
            *) DETAILED_DISTRO="$PRETTY_NAME" ;;
        esac
    else
        DETAILED_DISTRO=$(echo ${DISTRO^})
    fi
}

# ============================================================================
# 包管理器操作函数
# ============================================================================

# 更新软件包列表
package_update() {
    print_info "更新软件包列表..."
    log_message "开始更新软件包列表" "INFO"
    
    case $PACKAGE_MANAGER in
        apt)
            apt update
            ;;
        yum)
            yum check-update || true
            ;;
        dnf)
            dnf check-update || true
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
        xbps)
            xbps-install -S
            ;;
        emerge)
            emerge --sync
            ;;
        *)
            print_error "不支持的包管理器: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "软件包列表更新成功" "INFO"
    else
        log_message "软件包列表更新失败" "ERROR"
    fi
    
    return $result
}

# 升级系统软件包
package_upgrade() {
    print_info "升级系统软件包..."
    log_message "开始升级系统软件包" "INFO"
    
    case $PACKAGE_MANAGER in
        apt)
            apt upgrade -y
            ;;
        yum)
            yum upgrade -y
            ;;
        dnf)
            dnf upgrade -y
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
        xbps)
            xbps-install -u
            ;;
        emerge)
            emerge -uDN @world
            ;;
        *)
            print_error "不支持的包管理器: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "系统软件包升级成功" "INFO"
    else
        log_message "系统软件包升级失败" "ERROR"
    fi
    
    return $result
}

# 安装软件包
package_install() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        print_error "未指定要安装的软件包"
        return 1
    fi
    
    print_info "安装软件包: ${packages[*]}"
    log_message "开始安装软件包: ${packages[*]}" "INFO"
    
    case $PACKAGE_MANAGER in
        apt)
            apt install -y "${packages[@]}"
            ;;
        yum)
            yum install -y "${packages[@]}"
            ;;
        dnf)
            dnf install -y "${packages[@]}"
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
        xbps)
            xbps-install -y "${packages[@]}"
            ;;
        emerge)
            emerge "${packages[@]}"
            ;;
        *)
            print_error "不支持的包管理器: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "软件包安装成功: ${packages[*]}" "INFO"
    else
        log_message "软件包安装失败: ${packages[*]}" "ERROR"
    fi
    
    return $result
}

# 卸载软件包
package_remove() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        print_error "未指定要卸载的软件包"
        return 1
    fi
    
    print_info "卸载软件包: ${packages[*]}"
    log_message "开始卸载软件包: ${packages[*]}" "INFO"
    
    case $PACKAGE_MANAGER in
        apt)
            apt remove -y "${packages[@]}"
            ;;
        yum)
            yum remove -y "${packages[@]}"
            ;;
        dnf)
            dnf remove -y "${packages[@]}"
            ;;
        pacman)
            pacman -Rns --noconfirm "${packages[@]}"
            ;;
        zypper)
            zypper remove -y "${packages[@]}"
            ;;
        apk)
            apk del "${packages[@]}"
            ;;
        xbps)
            xbps-remove -y "${packages[@]}"
            ;;
        emerge)
            emerge -C "${packages[@]}"
            ;;
        *)
            print_error "不支持的包管理器: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "软件包卸载成功: ${packages[*]}" "INFO"
    else
        log_message "软件包卸载失败: ${packages[*]}" "ERROR"
    fi
    
    return $result
}

# 搜索软件包
package_search() {
    local keyword=$1
    
    if [[ -z "$keyword" ]]; then
        print_error "未指定搜索关键词"
        return 1
    fi
    
    print_info "搜索软件包: $keyword"
    
    case $PACKAGE_MANAGER in
        apt)
            apt search "$keyword"
            ;;
        yum)
            yum search "$keyword"
            ;;
        dnf)
            dnf search "$keyword"
            ;;
        pacman)
            pacman -Ss "$keyword"
            ;;
        zypper)
            zypper search "$keyword"
            ;;
        apk)
            apk search "$keyword"
            ;;
        xbps)
            xbps-query -Rs "$keyword"
            ;;
        emerge)
            emerge -s "$keyword"
            ;;
        *)
            print_error "不支持的包管理器: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
}

# ============================================================================
# 服务管理操作函数
# ============================================================================

# 启动服务
service_start() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        print_error "未指定服务名"
        return 1
    fi
    
    print_info "启动服务: $service"
    log_message "启动服务: $service" "INFO"
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl start "$service"
            ;;
        sysvinit)
            service "$service" start
            ;;
        openrc)
            rc-service "$service" start
            ;;
        *)
            print_error "不支持的服务管理器: $SERVICE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "服务启动成功: $service" "INFO"
    else
        log_message "服务启动失败: $service" "ERROR"
    fi
    
    return $result
}

# 停止服务
service_stop() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        print_error "未指定服务名"
        return 1
    fi
    
    print_info "停止服务: $service"
    log_message "停止服务: $service" "INFO"
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl stop "$service"
            ;;
        sysvinit)
            service "$service" stop
            ;;
        openrc)
            rc-service "$service" stop
            ;;
        *)
            print_error "不支持的服务管理器: $SERVICE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "服务停止成功: $service" "INFO"
    else
        log_message "服务停止失败: $service" "ERROR"
    fi
    
    return $result
}

# 重启服务
service_restart() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        print_error "未指定服务名"
        return 1
    fi
    
    print_info "重启服务: $service"
    log_message "重启服务: $service" "INFO"
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl restart "$service"
            ;;
        sysvinit)
            service "$service" restart
            ;;
        openrc)
            rc-service "$service" restart
            ;;
        *)
            print_error "不支持的服务管理器: $SERVICE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "服务重启成功: $service" "INFO"
    else
        log_message "服务重启失败: $service" "ERROR"
    fi
    
    return $result
}

# 启用服务自启动
service_enable() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        print_error "未指定服务名"
        return 1
    fi
    
    print_info "启用服务自启动: $service"
    log_message "启用服务自启动: $service" "INFO"
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl enable "$service"
            ;;
        sysvinit)
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig "$service" on
            elif command -v update-rc.d >/dev/null 2>&1; then
                update-rc.d "$service" enable
            else
                print_warning "无法设置服务自启动"
                return 1
            fi
            ;;
        openrc)
            rc-update add "$service" default
            ;;
        *)
            print_error "不支持的服务管理器: $SERVICE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "服务自启动设置成功: $service" "INFO"
    else
        log_message "服务自启动设置失败: $service" "ERROR"
    fi
    
    return $result
}

# 禁用服务自启动
service_disable() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        print_error "未指定服务名"
        return 1
    fi
    
    print_info "禁用服务自启动: $service"
    log_message "禁用服务自启动: $service" "INFO"
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl disable "$service"
            ;;
        sysvinit)
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig "$service" off
            elif command -v update-rc.d >/dev/null 2>&1; then
                update-rc.d "$service" disable
            else
                print_warning "无法禁用服务自启动"
                return 1
            fi
            ;;
        openrc)
            rc-update del "$service" default
            ;;
        *)
            print_error "不支持的服务管理器: $SERVICE_MANAGER"
            return 1
            ;;
    esac
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_message "服务自启动禁用成功: $service" "INFO"
    else
        log_message "服务自启动禁用失败: $service" "ERROR"
    fi
    
    return $result
}

# 查看服务状态
service_status() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        print_error "未指定服务名"
        return 1
    fi
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl status "$service" --no-pager -l
            ;;
        sysvinit)
            service "$service" status
            ;;
        openrc)
            rc-service "$service" status
            ;;
        *)
            print_error "不支务的服务管理器: $SERVICE_MANAGER"
            return 1
            ;;
    esac
}

# 检查服务是否运行
service_is_active() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        return 1
    fi
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl is-active "$service" >/dev/null 2>&1
            ;;
        sysvinit)
            service "$service" status >/dev/null 2>&1
            ;;
        openrc)
            rc-service "$service" status >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# 检查服务是否启用自启动
service_is_enabled() {
    local service=$1
    
    if [[ -z "$service" ]]; then
        return 1
    fi
    
    case $SERVICE_MANAGER in
        systemd)
            systemctl is-enabled "$service" >/dev/null 2>&1
            ;;
        sysvinit)
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig "$service" 2>/dev/null | grep -q "on"
            elif command -v systemctl >/dev/null 2>&1; then
                systemctl is-enabled "$service" >/dev/null 2>&1
            else
                return 1
            fi
            ;;
        openrc)
            rc-update show default | grep -q "$service"
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# 系统清理函数
# ============================================================================

# 清理包管理器缓存
clean_package_cache() {
    print_info "清理包管理器缓存..."
    
    case $PACKAGE_MANAGER in
        apt)
            apt autoremove -y
            apt autoclean
            apt clean
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
            # 清理孤立包
            pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || true
            # 清理缓存
            pacman -Scc --noconfirm
            ;;
        zypper)
            zypper clean --all
            ;;
        apk)
            apk cache clean
            ;;
        xbps)
            xbps-remove -O
            xbps-remove -o
            ;;
        emerge)
            emerge --depclean
            eclean distfiles
            eclean packages
            ;;
        *)
            print_warning "不支持的包管理器清理: $PACKAGE_MANAGER"
            ;;
    esac
}

# 清理临时文件
clean_temp_files() {
    print_info "清理临时文件..."
    
    # 清理 /tmp 目录下7天前的文件
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # 清理用户临时文件
    find /home/*/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # 清理系统临时文件
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
}

# 清理日志文件
clean_log_files() {
    print_info "清理旧日志文件..."
    
    # 使用journalctl清理systemd日志
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --vacuum-time=30d 2>/dev/null || true
        journalctl --vacuum-size=100M 2>/dev/null || true
    fi
    
    # 清理旧的轮转日志
    find /var/log -name "*.log.*.gz" -mtime +30 -delete 2>/dev/null || true
    find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
}

# 获取系统空间使用情况
get_disk_usage() {
    echo "磁盘使用情况:"
    df -h | grep -E '^/dev/'
    echo ""
    echo "最大的目录 (前10个):"
    du -sh /* 2>/dev/null | sort -hr | head -10
}
