#!/bin/bash

# 软件管理模块
# 作者: 東雪蓮 (Seren Azuma)

# 软件管理主菜单
software_management_menu() {
    while true; do
        clear
        print_header "软件管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "系统更新"
        print_menu_item "2" "安装常用工具"
        print_menu_item "3" "系统清理"
        print_menu_item "4" "显示已安装软件"
        print_menu_item "5" "搜索软件包"
        print_menu_item "6" "安装指定软件"
        print_menu_item "7" "卸载软件"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-7]: "
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
            5)
                echo ""
                search_packages
                ;;
            6)
                echo ""
                install_custom_package
                ;;
            7)
                echo ""
                remove_package
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选择，请输入0-7之间的数字"
                ;;
        esac
        
        wait_for_key $choice
    done
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

# 安装常用工具
install_common_tools() {
    print_header "安装常用工具软件"
    
    # 获取对应包管理器的工具包列表
    local basic_tools_str="${BASIC_TOOLS[$PACKAGE_MANAGER]}"
    local network_tools_str="${NETWORK_TOOLS[$PACKAGE_MANAGER]}"
    local dev_tools_str="${DEV_TOOLS[$PACKAGE_MANAGER]}"
    
    # 转换为数组
    read -ra basic_tools <<< "$basic_tools_str"
    read -ra network_tools <<< "$network_tools_str"
    read -ra dev_tools <<< "$dev_tools_str"
    
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
    if confirm_action "是否安装开发工具包？"; then
        print_info "安装开发工具..."
        if package_install "${dev_tools[@]}"; then
            print_success "开发工具安装完成"
        else
            print_warning "部分开发工具安装失败"
        fi
    fi
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
    if command_exists journalctl; then
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

# 搜索软件包
search_packages() {
    print_prompt "请输入要搜索的软件包名: "
    read -r package_name
    
    if [[ -z "$package_name" ]]; then
        print_error "软件包名不能为空"
        return 1
    fi
    
    print_info "搜索软件包: $package_name"
    
    case $PACKAGE_MANAGER in
        apt)
            apt search "$package_name" | head -20
            ;;
        yum|dnf)
            $PACKAGE_MANAGER search "$package_name" | head -20
            ;;
        pacman)
            pacman -Ss "$package_name" | head -20
            ;;
        zypper)
            zypper search "$package_name" | head -20
            ;;
        apk)
            apk search "$package_name" | head -20
            ;;
    esac
}

# 安装指定软件
install_custom_package() {
    print_prompt "请输入要安装的软件包名 (多个包用空格分隔): "
    read -r package_names
    
    if [[ -z "$package_names" ]]; then
        print_error "软件包名不能为空"
        return 1
    fi
    
    # 转换为数组
    read -ra packages <<< "$package_names"
    
    if confirm_action "确定要安装以下软件包吗？\n${packages[*]}"; then
        package_install "${packages[@]}"
        if [[ $? -eq 0 ]]; then
            print_success "软件包安装完成"
        else
            print_error "软件包安装失败"
        fi
    fi
}

# 卸载软件
remove_package() {
    print_prompt "请输入要卸载的软件包名 (多个包用空格分隔): "
    read -r package_names
    
    if [[ -z "$package_names" ]]; then
        print_error "软件包名不能为空"
        return 1
    fi
    
    # 转换为数组
    read -ra packages <<< "$package_names"
    
    if confirm_action "确定要卸载以下软件包吗？\n${packages[*]}"; then
        package_remove "${packages[@]}"
        if [[ $? -eq 0 ]]; then
            print_success "软件包卸载完成"
        else
            print_error "软件包卸载失败"
        fi
    fi
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
            4) kill_process ;;
            5) find_process ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 杀死进程
kill_process() {
    print_prompt "请输入进程PID: "
    read -r pid
    
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        print_error "无效的PID"
        return 1
    fi
    
    if confirm_action "确定要杀死进程 $pid 吗？"; then
        if kill "$pid" 2>/dev/null; then
            print_success "进程 $pid 已终止"
        else
            print_error "终止进程失败"
        fi
    fi
}

# 查找进程
find_process() {
    print_prompt "请输入进程名关键词: "
    read -r keyword
    
    if [[ -z "$keyword" ]]; then
        print_error "关键词不能为空"
        return 1
    fi
    
    ps aux | grep "$keyword" | grep -v grep
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
            2) check_directory_size ;;
            3) find_large_files ;;
            4) show_disk_io ;;
            5) mount | column -t ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 检查目录大小
check_directory_size() {
    print_prompt "请输入目录路径 [/]: "
    read -r dir_path
    dir_path=${dir_path:-/}
    
    if [[ ! -d "$dir_path" ]]; then
        print_error "目录不存在: $dir_path"
        return 1
    fi
    
    du -sh "$dir_path"/* 2>/dev/null | sort -hr | head -10
}

# 查找大文件
find_large_files() {
    print_prompt "请输入搜索路径 [/]: "
    read -r search_path
    print_prompt "请输入文件大小 (如 100M, 1G): "
    read -r file_size
    
    search_path=${search_path:-/}
    
    if [[ -z "$file_size" ]]; then
        print_error "文件大小不能为空"
        return 1
    fi
    
    find "$search_path" -type f -size +"$file_size" 2>/dev/null | head -10
}

# 显示磁盘IO统计
show_disk_io() {
    if command_exists iostat; then
        iostat -x 1 5
    else
        print_warning "iostat未安装，请安装sysstat包"
        print_info "安装命令: "
        echo "  Ubuntu/Debian: apt install sysstat"
        echo "  CentOS/RHEL: yum install sysstat"
        echo "  Fedora: dnf install sysstat"
        echo "  Arch: pacman -S sysstat"
    fi
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
            1) show_memory_usage ;;
            2) ps aux --sort=-%mem | head -10 ;;
            3) show_cache_info ;;
            4) show_swap_info ;;
            5) release_memory_cache ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 显示内存使用情况
show_memory_usage() {
    free -h
    echo ""
    cat /proc/meminfo | head -20
}

# 显示缓存信息
show_cache_info() {
    echo "页面缓存:"
    cat /proc/meminfo | grep -E "Cached|Buffers"
}

# 显示交换分区信息
show_swap_info() {
    free -h | grep Swap
    swapon --show 2>/dev/null || echo "无交换分区"
}

# 释放内存缓存
release_memory_cache() {
    if confirm_action "确定要释放内存缓存吗？"; then
        sync && echo 3 > /proc/sys/vm/drop_caches
        print_success "内存缓存已释放"
    fi
}

# 服务管理
service_management() {
    if [[ $SERVICE_MANAGER != "systemd" ]]; then
        print_warning "当前系统不支持systemd服务管理"
        return 1
    fi
    
    while true; do
        clear
        print_header "服务管理"
        
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
            3) start_service ;;
            4) stop_service ;;
            5) restart_service ;;
            6) enable_service ;;
            7) disable_service ;;
            8) show_service_logs ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 启动服务
start_service() {
    print_prompt "请输入服务名: "
    read -r service_name
    
    if [[ -z "$service_name" ]]; then
        print_error "服务名不能为空"
        return 1
    fi
    
    if service_start "$service_name"; then
        print_success "服务 $service_name 已启动"
    else
        print_error "服务 $service_name 启动失败"
    fi
}

# 停止服务
stop_service() {
    print_prompt "请输入服务名: "
    read -r service_name
    
    if [[ -z "$service_name" ]]; then
        print_error "服务名不能为空"
        return 1
    fi
    
    if confirm_action "确定要停止服务 $service_name 吗？"; then
        if service_stop "$service_name"; then
            print_success "服务 $service_name 已停止"
        else
            print_error "服务 $service_name 停止失败"
        fi
    fi
}

# 重启服务
restart_service() {
    print_prompt "请输入服务名: "
    read -r service_name
    
    if [[ -z "$service_name" ]]; then
        print_error "服务名不能为空"
        return 1
    fi
    
    if service_restart "$service_name"; then
        print_success "服务 $service_name 已重启"
    else
        print_error "服务 $service_name 重启失败"
    fi
}

# 启用服务
enable_service() {
    print_prompt "请输入服务名: "
    read -r service_name
    
    if [[ -z "$service_name" ]]; then
        print_error "服务名不能为空"
        return 1
    fi
    
    if service_enable "$service_name"; then
        print_success "服务 $service_name 已设为自启动"
    else
        print_error "服务 $service_name 设置自启动失败"
    fi
}

# 禁用服务
disable_service() {
    print_prompt "请输入服务名: "
    read -r service_name
    
    if [[ -z "$service_name" ]]; then
        print_error "服务名不能为空"
        return 1
    fi
    
    if service_disable "$service_name"; then
        print_success "服务 $service_name 已禁用自启动"
    else
        print_error "服务 $service_name 禁用自启动失败"
    fi
}

# 显示服务日志
show_service_logs() {
    print_prompt "请输入服务名: "
    read -r service_name
    
    if [[ -z "$service_name" ]]; then
        print_error "服务名不能为空"
        return 1
    fi
    
    journalctl -u "$service_name" -n 20 --no-pager
}
