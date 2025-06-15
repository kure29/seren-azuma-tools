#!/bin/bash

# 系统管理模块
# 作者: 東雪蓮 (Seren Azuma)

# 系统管理主菜单
system_management_menu() {
    while true; do
        clear
        print_header "系统管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "系统信息概览"
        print_menu_item "2" "更改系统密码"
        print_menu_item "3" "DNS配置"
        print_menu_item "4" "时区设置"
        print_menu_item "5" "用户管理"
        print_menu_item "6" "定时任务管理"
        print_menu_item "7" "系统工具"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-7]: "
        read -r choice
        
        case $choice in
            1) show_system_info ;;
            2) change_system_password ;;
            3) setup_dns ;;
            4) setup_timezone ;;
            5) user_management ;;
            6) cron_management ;;
            7) system_tools_menu ;;
            0) return ;;
            *) print_error "无效的选择，请输入0-7之间的数字" ;;
        esac
        
        [[ $choice != 7 ]] && wait_for_key $choice
    done
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
        username="${SUDO_USER:-root}"
    fi
    
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
    print_menu_item "1" "国内DNS (阿里云/腾讯/百度)"
    print_menu_item "2" "国际DNS (Google/Cloudflare/OpenDNS)"
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
    local dns_names=("阿里云" "腾讯" "百度")
    select_from_list "请选择国内DNS：" "${dns_names[@]}"
    local choice=$?
    
    [[ $choice -eq 0 ]] && return
    
    local selected_dns="${dns_names[$((choice-1))]}"
    set_dns_servers "${DNS_SERVERS[$selected_dns]}"
}

# 选择国际DNS
select_international_dns() {
    local dns_names=("Google" "Cloudflare" "OpenDNS" "Quad9")
    select_from_list "请选择国际DNS：" "${dns_names[@]}"
    local choice=$?
    
    [[ $choice -eq 0 ]] && return
    
    local selected_dns="${dns_names[$((choice-1))]}"
    set_dns_servers "${DNS_SERVERS[$selected_dns]}"
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
        sed -i '/^DNS=/d' /etc/systemd/resolved.conf
        sed -i '/^\[Resolve\]/a DNS='$primary_dns' '$secondary_dns /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
    else
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
    local backup_file=$(ls /etc/systemd/resolved.conf.bak.* 2>/dev/null | head -1)
    if [[ -n "$backup_file" ]]; then
        cp "$backup_file" /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
    else
        backup_file=$(ls /etc/resolv.conf.bak.* 2>/dev/null | head -1)
        if [[ -n "$backup_file" ]]; then
            cp "$backup_file" /etc/resolv.conf
        else
            # 使用DHCP默认DNS
            if command_exists dhclient; then
                dhclient -r && dhclient
            elif command_exists NetworkManager; then
                systemctl restart NetworkManager
            fi
        fi
    fi
    
    print_success "DNS已重置为系统默认"
}

# 时区设置
setup_timezone() {
    print_header "时区配置"
    
    print_info "当前时区设置："
    if command_exists timedatectl; then
        timedatectl show --property=Timezone --value
        timedatectl status
    else
        date
        cat /etc/timezone 2>/dev/null || echo "无法读取时区文件"
    fi
    
    echo ""
    local tz_names=("中国" "美东" "美西" "欧洲" "日本" "UTC")
    select_from_list "常用时区选择：" "${tz_names[@]}" "自定义时区" "查看所有可用时区"
    local choice=$?
    
    case $choice in
        0) return ;;
        7) custom_timezone_setup ;;
        8) show_all_timezones ;;
        *) 
            local selected_tz="${tz_names[$((choice-1))]}"
            set_timezone "${TIMEZONES[$selected_tz]}" "$selected_tz"
            ;;
    esac
}

# 设置时区
set_timezone() {
    local timezone=$1
    local tz_name=$2
    
    print_info "设置时区为 $tz_name ($timezone)..."
    
    if command_exists timedatectl; then
        if timedatectl set-timezone "$timezone"; then
            print_success "时区设置成功"
        else
            print_error "时区设置失败"
            return 1
        fi
    else
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
    if command_exists timedatectl; then
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
            3) add_user ;;
            4) delete_user ;;
            5) modify_user_group ;;
            6) lock_user ;;
            7) unlock_user ;;
            8) show_user_details ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 添加用户
add_user() {
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
}

# 删除用户
delete_user() {
    print_prompt "请输入要删除的用户名: "
    read -r username
    
    if ! confirm_action "确定要删除用户 $username 吗？"; then
        return 0
    fi
    
    print_prompt "是否删除家目录? (y/N): "
    read -r delete_home
    
    if [[ "$delete_home" =~ ^[Yy]$ ]]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi
    
    print_success "用户 $username 已删除"
}

# 修改用户组
modify_user_group() {
    print_prompt "请输入用户名: "
    read -r username
    print_prompt "请输入要添加的组: "
    read -r group
    
    usermod -aG "$group" "$username"
    print_success "用户 $username 已添加到组 $group"
}

# 锁定用户
lock_user() {
    print_prompt "请输入要锁定的用户名: "
    read -r username
    
    usermod -L "$username" && print_success "用户 $username 已锁定"
}

# 解锁用户
unlock_user() {
    print_prompt "请输入要解锁的用户名: "
    read -r username
    
    usermod -U "$username" && print_success "用户 $username 已解锁"
}

# 显示用户详情
show_user_details() {
    print_prompt "请输入用户名: "
    read -r username
    
    id "$username" 2>/dev/null || print_error "用户不存在"
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
            3) show_system_crontab ;;
            4) show_cron_logs ;;
            5) show_cron_help ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 显示系统定时任务
show_system_crontab() {
    echo "系统定时任务 (/etc/crontab):"
    cat /etc/crontab 2>/dev/null || print_info "系统定时任务文件不存在"
    echo ""
    echo "其他系统定时任务目录:"
    ls -la /etc/cron.* 2>/dev/null | head -10
}

# 显示cron日志
show_cron_logs() {
    if command_exists journalctl; then
        journalctl -u cron -n 20 --no-pager
    else
        tail -20 /var/log/cron 2>/dev/null || print_warning "无法找到cron日志"
    fi
}

# 显示cron语法帮助
show_cron_help() {
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
}

# 系统工具菜单
system_tools_menu() {
    while true; do
        clear
        print_header "系统工具"
        
        echo -e "${BOLD}请选择工具:${NC}"
        print_menu_item "1" "进程管理"
        print_menu_item "2" "磁盘管理"
        print_menu_item "3" "内存分析"
        print_menu_item "4" "服务管理"
        print_menu_item "5" "系统清理"
        print_menu_item "0" "返回"
        
        print_prompt "请选择工具 [0-5]: "
        read -r choice
        
        case $choice in
            1) process_management ;;
            2) disk_management ;;
            3) memory_analysis ;;
            4) service_management ;;
            5) system_cleanup ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}
