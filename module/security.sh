#!/bin/bash

# 安全管理模块
# 作者: 東雪蓮 (Seren Azuma)

# 安全管理主菜单
security_management_menu() {
    while true; do
        clear
        print_header "安全管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "SSH管理"
        print_menu_item "2" "UFW防火墙管理"
        print_menu_item "3" "Fail2ban管理"
        print_menu_item "4" "系统安全扫描"
        print_menu_item "5" "SSL证书管理"
        print_menu_item "6" "安全日志分析"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) manage_ssh ;;
            2) manage_firewall ;;
            3) manage_fail2ban ;;
            4) security_scan ;;
            5) ssl_management ;;
            6) security_log_analysis ;;
            0) return ;;
            *) print_error "无效的选择，请输入0-6之间的数字" ;;
        esac
        
        wait_for_key $choice
    done
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
        if command_exists fail2ban-client; then
            echo "  Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo "未知")"
        else
            echo "  Fail2ban: 未安装"
        fi
        
        print_separator
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看SSH日志"
        print_menu_item "2" "重启SSH服务"
        print_menu_item "3" "修改SSH端口"
        print_menu_item "4" "配置SSH密钥登录"
        print_menu_item "5" "禁用密码登录"
        print_menu_item "6" "SSH安全加固"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) view_ssh_logs ;;
            2) restart_ssh_service ;;
            3) change_ssh_port ;;
            4) setup_ssh_keys ;;
            5) disable_password_auth ;;
            6) ssh_security_hardening ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 查看SSH日志
view_ssh_logs() {
    print_info "查看SSH日志"
    if command_exists journalctl; then
        journalctl -u ssh -u sshd -n 20 --no-pager
    elif [[ -f /var/log/auth.log ]]; then
        tail -20 /var/log/auth.log | grep ssh
    elif [[ -f /var/log/secure ]]; then
        tail -20 /var/log/secure | grep ssh
    else
        print_warning "无法找到SSH日志文件"
    fi
}

# 重启SSH服务
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

# 修改SSH端口
change_ssh_port() {
    print_header "修改SSH端口"
    
    local current_port=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    current_port=${current_port:-22}
    
    print_info "当前SSH端口: $current_port"
    print_prompt "请输入新的SSH端口 (1024-65535): "
    read -r new_port
    
    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1024 ]] || [[ "$new_port" -gt 65535 ]]; then
        print_error "端口号无效，请输入1024-65535之间的数字"
        return 1
    fi
    
    # 检查端口是否被占用
    if netstat -tuln 2>/dev/null | grep -q ":$new_port "; then
        print_error "端口 $new_port 已被占用"
        return 1
    fi
    
    if confirm_action "确定要将SSH端口改为 $new_port 吗？"; then
        # 备份配置文件
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)
        
        # 修改端口
        if grep -q "^Port" /etc/ssh/sshd_config; then
            sed -i "s/^Port.*/Port $new_port/" /etc/ssh/sshd_config
        else
            echo "Port $new_port" >> /etc/ssh/sshd_config
        fi
        
        # 重启SSH服务
        if restart_ssh_service; then
            print_success "SSH端口已修改为 $new_port"
            print_warning "请确保防火墙允许新端口，否则可能无法连接"
            
            # 自动配置UFW防火墙
            if command_exists ufw && ufw status | grep -q "Status: active"; then
                if confirm_action "是否自动配置UFW防火墙允许新端口？"; then
                    ufw allow "$new_port"/tcp
                    print_success "防火墙规则已添加"
                fi
            fi
        else
            print_error "SSH服务重启失败，请检查配置"
        fi
    fi
}

# 配置SSH密钥登录
setup_ssh_keys() {
    print_header "配置SSH密钥登录"
    
    print_prompt "请输入要配置密钥登录的用户名: "
    read -r target_user
    
    if [[ -z "$target_user" ]]; then
        print_error "用户名不能为空"
        return 1
    fi
    
    if ! id "$target_user" >/dev/null 2>&1; then
        print_error "用户 $target_user 不存在"
        return 1
    fi
    
    local user_home=$(eval echo "~$target_user")
    local ssh_dir="$user_home/.ssh"
    local authorized_keys="$ssh_dir/authorized_keys"
    
    # 创建.ssh目录
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chown "$target_user:$target_user" "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    
    # 创建authorized_keys文件
    if [[ ! -f "$authorized_keys" ]]; then
        touch "$authorized_keys"
        chown "$target_user:$target_user" "$authorized_keys"
        chmod 600 "$authorized_keys"
    fi
    
    print_info "请选择操作："
    print_menu_item "1" "生成新的SSH密钥对"
    print_menu_item "2" "添加现有公钥"
    print_menu_item "3" "查看已授权的公钥"
    
    print_prompt "请选择 [1-3]: "
    read -r key_choice
    
    case $key_choice in
        1)
            # 生成新密钥对
            local key_path="$ssh_dir/id_rsa"
            if [[ -f "$key_path" ]]; then
                if ! confirm_action "密钥文件已存在，是否覆盖？"; then
                    return 0
                fi
            fi
            
            su - "$target_user" -c "ssh-keygen -t rsa -b 4096 -f $key_path -N ''"
            cat "$key_path.pub" >> "$authorized_keys"
            print_success "SSH密钥对生成完成"
            print_info "私钥位置: $key_path"
            print_info "公钥位置: $key_path.pub"
            ;;
        2)
            # 添加现有公钥
            print_prompt "请粘贴公钥内容: "
            read -r public_key
            if [[ -n "$public_key" ]]; then
                echo "$public_key" >> "$authorized_keys"
                print_success "公钥已添加"
            fi
            ;;
        3)
            # 查看已授权的公钥
            if [[ -f "$authorized_keys" ]]; then
                cat "$authorized_keys"
            else
                print_info "未找到已授权的公钥"
            fi
            ;;
    esac
}

# 禁用密码登录
disable_password_auth() {
    print_header "禁用SSH密码登录"
    
    print_warning "禁用密码登录前，请确保已配置SSH密钥登录"
    print_warning "否则可能导致无法连接服务器"
    
    if ! confirm_action "确定要禁用SSH密码登录吗？"; then
        return 0
    fi
    
    # 备份配置文件
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)
    
    # 禁用密码认证
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # 禁用质询响应认证
    sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    
    # 重启SSH服务
    if restart_ssh_service; then
        print_success "SSH密码登录已禁用"
        print_info "现在只能使用SSH密钥登录"
    else
        print_error "SSH服务重启失败，请检查配置"
    fi
}

# SSH安全加固
ssh_security_hardening() {
    print_header "SSH安全加固"
    
    if ! confirm_action "确定要进行SSH安全加固吗？"; then
        return 0
    fi
    
    # 备份配置文件
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)
    
    print_info "正在进行SSH安全加固..."
    
    # 禁用root登录
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # 设置登录超时
    sed -i 's/#LoginGraceTime.*/LoginGraceTime 60/' /etc/ssh/sshd_config
    
    # 限制最大认证尝试次数
    sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    
    # 禁用空密码
    sed -i 's/#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    
    # 禁用X11转发
    sed -i 's/#X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
    sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
    
    # 添加ClientAliveInterval
    if ! grep -q "ClientAliveInterval" /etc/ssh/sshd_config; then
        echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
        echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config
    fi
    
    # 重启SSH服务
    if restart_ssh_service; then
        print_success "SSH安全加固完成"
        echo "  - 禁用root登录"
        echo "  - 设置登录超时为60秒"
        echo "  - 限制最大认证尝试次数为3次"
        echo "  - 禁用空密码登录"
        echo "  - 禁用X11转发"
        echo "  - 设置客户端保活间隔"
    else
        print_error "SSH服务重启失败，请检查配置"
    fi
}

# UFW防火墙管理
manage_firewall() {
    clear
    print_header "UFW防火墙管理"
    
    # 检查UFW是否已安装
    if ! command_exists ufw; then
        print_warning "UFW未安装"
        echo ""
        if confirm_action "是否安装UFW？"; then
            print_info "安装UFW..."
            package_install ufw
            if command_exists ufw; then
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
            1) ufw_enable ;;
            2) ufw_disable ;;
            3) ufw_allow_port ;;
            4) ufw_deny_port ;;
            5) ufw_delete_rule ;;
            6) ufw_status_numbered ;;
            7) ufw_reset ;;
            8) configure_common_services ;;
            9) configure_default_policy ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
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
    status_output=$(echo "$status_output" | sed 's/ALLOW/允许/g')
    status_output=$(echo "$status_output" | sed 's/DENY/拒绝/g')
    status_output=$(echo "$status_output" | sed 's/Anywhere/任何地址/g')
    
    echo "$status_output"
}

# UFW命令中文化执行
ufw_chinese() {
    local cmd="$1"
    shift
    local args="$@"
    
    local output
    case "$cmd" in
        "enable")
            output=$(echo "y" | ufw enable 2>&1)
            ;;
        "disable")
            output=$(ufw disable 2>&1)
            ;;
        "reset")
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
    output=$(echo "$output" | sed 's/Firewall is active and enabled on system startup/防火墙已激活并在系统启动时自动启用/g')
    output=$(echo "$output" | sed 's/Firewall stopped and disabled on system startup/防火墙已停止并在系统启动时禁用/g')
    output=$(echo "$output" | sed 's/Rules updated/规则已更新/g')
    output=$(echo "$output" | sed 's/Rule added/规则已添加/g')
    output=$(echo "$output" | sed 's/Rule deleted/规则已删除/g')
    
    echo "$output"
}

# 启用UFW
ufw_enable() {
    ufw_chinese "enable"
    print_success "防火墙已启用"
}

# 禁用UFW
ufw_disable() {
    ufw_chinese "disable"
    print_success "防火墙已禁用"
}

# 开放端口
ufw_allow_port() {
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
}

# 关闭端口
ufw_deny_port() {
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
}

# 删除规则
ufw_delete_rule() {
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
}

# 查看详细规则
ufw_status_numbered() {
    translate_ufw_status "$(ufw status numbered)"
}

# 重置UFW
ufw_reset() {
    if confirm_action "确定要重置所有防火墙规则吗？"; then
        ufw_chinese "reset"
        print_success "防火墙已重置"
    fi
}

# 配置常用服务
configure_common_services() {
    print_header "配置常用服务端口"
    
    local services=("SSH (22)" "HTTP (80)" "HTTPS (443)" "FTP (21)" "MySQL (3306)" "PostgreSQL (5432)" "Redis (6379)" "MongoDB (27017)" "全部常用服务")
    select_from_list "请选择要开放的服务：" "${services[@]}"
    local choice=$?
    
    case $choice in
        0) return ;;
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
            return
            ;;
    esac
    
    [[ $choice != 0 ]] && print_success "服务端口已配置"
}

# 配置默认策略
configure_default_policy() {
    print_header "配置默认策略"
    
    echo "当前默认策略:"
    translate_ufw_status "$(ufw status verbose | grep "Default:")"
    echo ""
    
    local policies=("默认拒绝入站，允许出站 (推荐)" "默认允许入站，允许出站" "默认拒绝所有")
    select_from_list "请选择默认策略：" "${policies[@]}"
    local choice=$?
    
    case $choice in
        0) return ;;
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
    esac
}

# Fail2ban管理
manage_fail2ban() {
    while true; do
        clear
        print_header "Fail2ban管理"
        
        # 显示Fail2ban状态
        echo -e "${CYAN}◆ Fail2ban状态${NC}"
        if command_exists fail2ban-client; then
            echo "  安装状态: 已安装"
            echo "  服务状态: $(systemctl is-active fail2ban 2>/dev/null || echo "未知")"
            if systemctl is-active fail2ban >/dev/null 2>&1; then
                echo "  监狱状态:"
                fail2ban-client status 2>/dev/null | grep "Jail list:" | sed 's/.*: /    /'
            fi
        else
            echo "  安装状态: 未安装"
        fi
        
        print_separator
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "安装Fail2ban"
        print_menu_item "2" "启用SSH保护"
        print_menu_item "3" "查看被封IP"
        print_menu_item "4" "解封指定IP"
        print_menu_item "5" "查看Fail2ban日志"
        print_menu_item "6" "配置监狱规则"
        print_menu_item "7" "卸载Fail2ban"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-7]: "
        read -r choice
        
        case $choice in
            1) install_fail2ban ;;
            2) configure_fail2ban_ssh ;;
            3) show_banned_ips ;;
            4) unban_ip ;;
            5) show_fail2ban_logs ;;
            6) configure_fail2ban_jails ;;
            7) uninstall_fail2ban ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 安装Fail2ban
install_fail2ban() {
    print_header "安装Fail2ban"
    
    if command_exists fail2ban-client; then
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

# 配置Fail2ban SSH保护
configure_fail2ban_ssh() {
    if ! command_exists fail2ban-client; then
        print_error "Fail2ban未安装，请先安装"
        return 1
    fi
    
    print_header "配置Fail2ban SSH保护"
    
    # 创建基本配置
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# 封禁时间（秒）
bantime = 3600
# 检测时间窗口（秒）
findtime = 600
# 最大重试次数
maxretry = 5
# 忽略的IP地址
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
    
    # 如果是CentOS/RHEL系统，修改日志路径
    if [[ "$PACKAGE_MANAGER" == "yum" || "$PACKAGE_MANAGER" == "dnf" ]]; then
        sed -i 's|/var/log/auth.log|/var/log/secure|' /etc/fail2ban/jail.local
    fi
    
    service_restart fail2ban
    print_success "SSH保护已启用"
    
    # 显示配置信息
    echo ""
    echo "配置信息："
    echo "  封禁时间: 1小时"
    echo "  检测窗口: 10分钟"
    echo "  最大重试: 3次"
    echo "  监控端口: SSH"
}

# 查看被封IP
show_banned_ips() {
    if ! command_exists fail2ban-client; then
        print_error "Fail2ban未安装"
        return 1
    fi
    
    if ! systemctl is-active fail2ban >/dev/null 2>&1; then
        print_error "Fail2ban服务未运行"
        return 1
    fi
    
    print_info "查看被封IP地址:"
    fail2ban-client status sshd 2>/dev/null || print_warning "SSH jail未配置或未激活"
}

# 解封IP
unban_ip() {
    if ! command_exists fail2ban-client; then
        print_error "Fail2ban未安装"
        return 1
    fi
    
    print_prompt "请输入要解封的IP地址: "
    read -r ip_to_unban
    
    if [[ -z "$ip_to_unban" ]]; then
        print_error "IP地址不能为空"
        return 1
    fi
    
    if fail2ban-client set sshd unbanip "$ip_to_unban" 2>/dev/null; then
        print_success "IP $ip_to_unban 已解封"
    else
        print_error "解封失败，请检查IP地址是否正确"
    fi
}

# 查看Fail2ban日志
show_fail2ban_logs() {
    if [[ -f /var/log/fail2ban.log ]]; then
        tail -20 /var/log/fail2ban.log
    else
        print_warning "无法找到Fail2ban日志文件"
    fi
}

# 配置Fail2ban监狱规则
configure_fail2ban_jails() {
    print_header "配置Fail2ban监狱规则"
    
    local jails=("SSH暴力破解保护" "HTTP防护" "Nginx防护" "Apache防护" "自定义规则")
    select_from_list "请选择要配置的监狱：" "${jails[@]}"
    local choice=$?
    
    case $choice in
        0) return ;;
        1) 
            print_info "SSH保护已在基本配置中启用"
            ;;
        2)
            configure_http_jail
            ;;
        3)
            configure_nginx_jail
            ;;
        4)
            configure_apache_jail
            ;;
        5)
            configure_custom_jail
            ;;
    esac
}

# 配置HTTP监狱
configure_http_jail() {
    cat >> /etc/fail2ban/jail.local << 'EOF'

[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/nginx/access.log
maxretry = 300
findtime = 300
bantime = 600
action = iptables[name=HTTP, port=http, protocol=tcp]
EOF
    
    # 创建过滤器
    cat > /etc/fail2ban/filter.d/http-get-dos.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*
ignoreregex =
EOF
    
    service_restart fail2ban
    print_success "HTTP DoS保护已启用"
}

# 配置Nginx监狱
configure_nginx_jail() {
    cat >> /etc/fail2ban/jail.local << 'EOF'

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 600
bantime = 7200
EOF
    
    service_restart fail2ban
    print_success "Nginx保护已启用"
}

# 配置Apache监狱
configure_apache_jail() {
    cat >> /etc/fail2ban/jail.local << 'EOF'

[apache-auth]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache*/*error.log
maxretry = 6

[apache-badbots]
enabled = true
port = http,https
filter = apache-badbots
logpath = /var/log/apache*/*access.log
maxretry = 2
EOF
    
    service_restart fail2ban
    print_success "Apache保护已启用"
}

# 配置自定义监狱
configure_custom_jail() {
    print_prompt "请输入监狱名称: "
    read -r jail_name
    print_prompt "请输入日志文件路径: "
    read -r log_path
    print_prompt "请输入最大重试次数 [5]: "
    read -r max_retry
    max_retry=${max_retry:-5}
    
    if [[ -z "$jail_name" || -z "$log_path" ]]; then
        print_error "监狱名称和日志路径不能为空"
        return 1
    fi
    
    cat >> /etc/fail2ban/jail.local << EOF

[$jail_name]
enabled = true
filter = $jail_name
logpath = $log_path
maxretry = $max_retry
bantime = 3600
findtime = 600
EOF
    
    print_info "请手动创建过滤器文件: /etc/fail2ban/filter.d/$jail_name.conf"
    print_success "自定义监狱已添加"
}

# 卸载Fail2ban
uninstall_fail2ban() {
    if ! command_exists fail2ban-client; then
        print_info "Fail2ban未安装，无需卸载"
        return 0
    fi
    
    if confirm_action "确定要卸载Fail2ban吗？"; then
        service_stop fail2ban
        service_disable fail2ban
        package_remove fail2ban
        print_success "Fail2ban已卸载"
    fi
}

# 系统安全扫描
security_scan() {
    print_header "系统安全扫描"
    
    print_info "开始安全扫描..."
    
    # 检查系统更新
    echo ""
    echo -e "${CYAN}◆ 系统更新检查${NC}"
    case $PACKAGE_MANAGER in
        apt)
            apt list --upgradable 2>/dev/null | wc -l | awk '{print "可更新软件包: " $1-1 " 个"}'
            ;;
        yum|dnf)
            $PACKAGE_MANAGER check-update 2>/dev/null | grep -v "^$" | wc -l | awk '{print "可更新软件包: " $1 " 个"}'
            ;;
        pacman)
            pacman -Qu 2>/dev/null | wc -l | awk '{print "可更新软件包: " $1 " 个"}'
            ;;
    esac
    
    # 检查开放端口
    echo ""
    echo -e "${CYAN}◆ 开放端口检查${NC}"
    if command_exists ss; then
        ss -tuln | grep LISTEN | head -10
    else
        netstat -tuln | grep LISTEN | head -10
    fi
    
    # 检查登录失败记录
    echo ""
    echo -e "${CYAN}◆ 登录失败记录${NC}"
    if [[ -f /var/log/auth.log ]]; then
        grep "Failed password" /var/log/auth.log | tail -5
    elif [[ -f /var/log/secure ]]; then
        grep "Failed password" /var/log/secure | tail -5
    else
        echo "未找到认证日志文件"
    fi
    
    # 检查SSH配置
    echo ""
    echo -e "${CYAN}◆ SSH安全配置检查${NC}"
    local ssh_config="/etc/ssh/sshd_config"
    if [[ -f "$ssh_config" ]]; then
        echo "Root登录: $(grep "^PermitRootLogin" "$ssh_config" || echo "默认允许")"
        echo "密码认证: $(grep "^PasswordAuthentication" "$ssh_config" || echo "默认允许")"
        echo "SSH端口: $(grep "^Port" "$ssh_config" | awk '{print $2}' || echo "22 (默认)")"
    fi
    
    # 检查防火墙状态
    echo ""
    echo -e "${CYAN}◆ 防火墙状态检查${NC}"
    if command_exists ufw; then
        ufw status | head -3
    elif command_exists iptables; then
        iptables -L | head -5
    else
        echo "未检测到防火墙"
    fi
    
    # 检查异常进程
    echo ""
    echo -e "${CYAN}◆ 系统负载检查${NC}"
    echo "CPU负载: $(uptime | awk -F'load average:' '{print $2}')"
    echo "内存使用: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "磁盘使用: $(df / | awk 'NR==2{print $5}')"
    
    print_success "安全扫描完成"
}

# SSL证书管理
ssl_management() {
    while true; do
        clear
        print_header "SSL证书管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "安装Certbot"
        print_menu_item "2" "申请Let's Encrypt证书"
        print_menu_item "3" "续签证书"
        print_menu_item "4" "查看证书信息"
        print_menu_item "5" "删除证书"
        print_menu_item "6" "测试证书自动续签"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) install_certbot ;;
            2) request_ssl_certificate ;;
            3) renew_ssl_certificate ;;
            4) show_ssl_info ;;
            5) delete_ssl_certificate ;;
            6) test_ssl_renewal ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 安装Certbot
install_certbot() {
    print_header "安装Certbot"
    
    if command_exists certbot; then
        print_warning "Certbot已安装"
        certbot --version
        return 0
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            package_install certbot python3-certbot-nginx python3-certbot-apache
            ;;
        yum|dnf)
            package_install certbot python3-certbot-nginx python3-certbot-apache
            ;;
        pacman)
            package_install certbot certbot-nginx certbot-apache
            ;;
        *)
            print_error "不支持的包管理器"
            return 1
            ;;
    esac
    
    if command_exists certbot; then
        print_success "Certbot安装成功"
        certbot --version
    else
        print_error "Certbot安装失败"
    fi
}

# 申请SSL证书
request_ssl_certificate() {
    if ! command_exists certbot; then
        print_error "Certbot未安装，请先安装"
        return 1
    fi
    
    print_prompt "请输入域名: "
    read -r domain
    print_prompt "请输入邮箱地址: "
    read -r email
    
    if [[ -z "$domain" || -z "$email" ]]; then
        print_error "域名和邮箱不能为空"
        return 1
    fi
    
    # 选择验证方式
    local methods=("Nginx" "Apache" "独立模式" "仅获取证书")
    select_from_list "请选择验证方式：" "${methods[@]}"
    local choice=$?
    
    case $choice in
        0) return ;;
        1) certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive ;;
        2) certbot --apache -d "$domain" --email "$email" --agree-tos --non-interactive ;;
        3) certbot certonly --standalone -d "$domain" --email "$email" --agree-tos --non-interactive ;;
        4) certbot certonly --manual -d "$domain" --email "$email" --agree-tos --non-interactive ;;
    esac
}

# 续签证书
renew_ssl_certificate() {
    if ! command_exists certbot; then
        print_error "Certbot未安装"
        return 1
    fi
    
    print_info "续签所有证书..."
    certbot renew
}

# 查看证书信息
show_ssl_info() {
    if ! command_exists certbot; then
        print_error "Certbot未安装"
        return 1
    fi
    
    certbot certificates
}

# 删除证书
delete_ssl_certificate() {
    if ! command_exists certbot; then
        print_error "Certbot未安装"
        return 1
    fi
    
    print_prompt "请输入要删除的域名: "
    read -r domain
    
    if [[ -z "$domain" ]]; then
        print_error "域名不能为空"
        return 1
    fi
    
    if confirm_action "确定要删除域名 $domain 的证书吗？"; then
        certbot delete --cert-name "$domain"
    fi
}

# 测试证书自动续签
test_ssl_renewal() {
    if ! command_exists certbot; then
        print_error "Certbot未安装"
        return 1
    fi
    
    print_info "测试证书自动续签..."
    certbot renew --dry-run
}

# 安全日志分析
security_log_analysis() {
    print_header "安全日志分析"
    
    # SSH登录分析
    echo -e "${CYAN}◆ SSH登录分析${NC}"
    if [[ -f /var/log/auth.log ]]; then
        echo "最近10次SSH登录:"
        grep "Accepted" /var/log/auth.log | tail -10 | awk '{print $1, $2, $3, $9, $11}'
        echo ""
        echo "SSH登录失败统计:"
        grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -nr | head -10
    elif [[ -f /var/log/secure ]]; then
        echo "最近10次SSH登录:"
        grep "Accepted" /var/log/secure | tail -10 | awk '{print $1, $2, $3, $9, $11}'
        echo ""
        echo "SSH登录失败统计:"
        grep "Failed password" /var/log/secure | awk '{print $11}' | sort | uniq -c | sort -nr | head -10
    else
        echo "未找到SSH日志文件"
    fi
    
    # 系统启动分析
    echo ""
    echo -e "${CYAN}◆ 系统启动分析${NC}"
    if command_exists journalctl; then
        echo "最近5次系统启动:"
        journalctl --list-boots | tail -5
    else
        echo "无法获取启动日志"
    fi
    
    # 磁盘空间警告
    echo ""
    echo -e "${CYAN}◆ 磁盘空间检查${NC}"
    df -h | awk '$5 > 80 {print "警告: " $6 " 使用率 " $5}'
    
    # 内存使用分析
    echo ""
    echo -e "${CYAN}◆ 内存使用分析${NC}"
    free -h | awk 'NR==2{printf "内存使用率: %.1f%%\n", $3*100/$2}'
    
    # 网络连接分析
    echo ""
    echo -e "${CYAN}◆ 网络连接分析${NC}"
    if command_exists ss; then
        echo "当前连接数: $(ss -tun | wc -l)"
        echo "监听端口:"
        ss -tuln | grep LISTEN | awk '{print $5}' | sort | uniq
    else
        echo "当前连接数: $(netstat -tun | wc -l)"
        echo "监听端口:"
        netstat -tuln | grep LISTEN | awk '{print $4}' | sort | uniq
    fi
}
