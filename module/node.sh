#!/bin/bash

# 节点部署模块
# 作者: 東雪蓮 (Seren Azuma)

# 节点部署主菜单
node_deployment_menu() {
    while true; do
        clear
        print_header "节点搭建"
        
        echo -e "${WHITE}注意: 节点搭建需要网络连接，请确保服务器可以访问外网${NC}"
        
        print_separator
        echo -e "${BOLD}请选择要搭建的节点:${NC}"
        print_menu_item "1" "Snell 代理节点"
        print_menu_item "2" "3X-UI 面板"
        print_menu_item "3" "V2Ray 节点"
        print_menu_item "4" "Trojan 节点"
        print_menu_item "5" "Shadowsocks 节点"
        print_menu_item "6" "WireGuard VPN"
        print_menu_item "7" "OpenVPN 服务器"
        print_menu_item "8" "节点管理"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择要搭建的节点 [0-8]: "
        read -r choice
        
        case $choice in
            1) deploy_snell_node ;;
            2) deploy_3xui_panel ;;
            3) deploy_v2ray_node ;;
            4) deploy_trojan_node ;;
            5) deploy_shadowsocks_node ;;
            6) deploy_wireguard_vpn ;;
            7) deploy_openvpn_server ;;
            8) node_management_menu ;;
            0) return ;;
            *) print_error "无效的选择，请输入0-8之间的数字" ;;
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
    
    if ! confirm_action "确定要开始部署Snell节点吗？"; then
        print_info "取消部署"
        return 0
    fi
    
    print_info "下载并执行Snell一键安装脚本..."
    print_warning "脚本将自动配置Snell服务，请按照提示操作"
    
    # 下载并执行Snell脚本
    if wget -O snell.sh --no-check-certificate https://git.io/Snell.sh 2>/dev/null; then
        chmod +x snell.sh
        print_success "Snell脚本下载成功，开始执行..."
        echo ""
        ./snell.sh
    else
        print_error "Snell脚本下载失败，尝试备用链接..."
        if curl -L -o snell.sh https://raw.githubusercontent.com/surge-networks/snell/master/install.sh 2>/dev/null; then
            chmod +x snell.sh
            ./snell.sh
        else
            print_error "无法下载Snell脚本，请检查网络连接"
            return 1
        fi
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
    if command_exists x-ui && systemctl list-unit-files | grep -q "x-ui.service"; then
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
    
    if ! confirm_action "是否要安装3X-UI面板？"; then
        print_info "取消安装"
        return 0
    fi
    
    print_info "下载并执行3X-UI一键安装脚本..."
    print_warning "脚本将自动安装并配置3X-UI面板，请按照提示操作"
    
    echo ""
    # 执行3X-UI安装脚本
    if bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) 2>/dev/null; then
        print_success "3X-UI安装完成"
        
        # 检查并启动xray
        check_and_start_xray
        
        # 安装完成后提示进入管理界面
        echo ""
        echo -ne "${CYAN}按回车键进入3X-UI管理面板...${NC}"
        read -r
        
        if command_exists x-ui; then
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

# 部署V2Ray节点
deploy_v2ray_node() {
    clear
    print_header "V2Ray 节点部署"
    
    print_info "V2Ray是一个功能强大的网络代理工具"
    
    if ! check_network; then
        print_error "网络连接失败，无法下载V2Ray"
        return 1
    fi
    
    # 检查是否已安装
    if command_exists v2ray; then
        print_warning "V2Ray已安装"
        if confirm_action "是否重新配置V2Ray？"; then
            configure_v2ray
        fi
        return 0
    fi
    
    if ! confirm_action "确定要安装V2Ray吗？"; then
        return 0
    fi
    
    print_info "安装V2Ray..."
    
    # 使用官方安装脚本
    if bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) 2>/dev/null; then
        print_success "V2Ray安装成功"
        
        # 配置V2Ray
        configure_v2ray
        
        # 启动服务
        systemctl enable v2ray
        systemctl start v2ray
        
        if systemctl is-active v2ray >/dev/null 2>&1; then
            print_success "V2Ray服务启动成功"
        else
            print_error "V2Ray服务启动失败"
        fi
    else
        print_error "V2Ray安装失败"
    fi
}

# 配置V2Ray
configure_v2ray() {
    print_info "配置V2Ray..."
    
    # 生成UUID
    local uuid
    if command_exists uuidgen; then
        uuid=$(uuidgen)
    else
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    
    print_prompt "请输入监听端口 [8080]: "
    read -r port
    port=${port:-8080}
    
    # 创建配置文件
    cat > /usr/local/etc/v2ray/config.json << EOF
{
  "inbounds": [{
    "port": $port,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "level": 1,
        "alterId": 0
      }]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    
    print_success "V2Ray配置完成"
    print_info "客户端配置信息："
    echo "  协议: VMess"
    echo "  地址: $(curl -s ipv4.icanhazip.com 2>/dev/null || echo "您的服务器IP")"
    echo "  端口: $port"
    echo "  UUID: $uuid"
    echo "  额外ID: 0"
}

# 部署Trojan节点
deploy_trojan_node() {
    clear
    print_header "Trojan 节点部署"
    
    print_info "Trojan是一个轻量级的代理协议"
    
    if ! check_network; then
        print_error "网络连接失败"
        return 1
    fi
    
    if command_exists trojan; then
        print_warning "Trojan已安装"
        return 0
    fi
    
    if ! confirm_action "确定要安装Trojan吗？"; then
        return 0
    fi
    
    # 安装依赖
    case $PACKAGE_MANAGER in
        apt)
            package_install wget curl
            ;;
        yum|dnf)
            package_install wget curl
            ;;
        *)
            print_warning "请手动安装wget和curl"
            ;;
    esac
    
    # 下载并安装Trojan
    print_info "下载Trojan一键安装脚本..."
    if bash <(curl -sL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh) 2>/dev/null; then
        print_success "Trojan安装完成"
    else
        print_error "Trojan安装失败"
    fi
}

# 部署Shadowsocks节点
deploy_shadowsocks_node() {
    clear
    print_header "Shadowsocks 节点部署"
    
    print_info "Shadowsocks是一个经典的代理协议"
    
    if ! check_network; then
        print_error "网络连接失败"
        return 1
    fi
    
    local ss_methods=("手动安装配置" "使用一键脚本")
    select_from_list "请选择安装方式：" "${ss_methods[@]}"
    local choice=$?
    
    case $choice in
        0) return ;;
        1) install_shadowsocks_manual ;;
        2) install_shadowsocks_script ;;
    esac
}

# 手动安装Shadowsocks
install_shadowsocks_manual() {
    print_info "手动安装Shadowsocks服务器..."
    
    # 安装shadowsocks-libev
    case $PACKAGE_MANAGER in
        apt)
            package_install shadowsocks-libev
            ;;
        yum|dnf)
            package_install epel-release
            package_install shadowsocks-libev
            ;;
        pacman)
            package_install shadowsocks
            ;;
        *)
            print_error "不支持的包管理器"
            return 1
            ;;
    esac
    
    # 配置Shadowsocks
    print_prompt "请输入监听端口 [8388]: "
    read -r ss_port
    ss_port=${ss_port:-8388}
    
    print_prompt "请输入密码: "
    read -r ss_password
    
    if [[ -z "$ss_password" ]]; then
        print_error "密码不能为空"
        return 1
    fi
    
    local ss_methods_list=("aes-256-gcm" "chacha20-ietf-poly1305" "aes-128-gcm")
    select_from_list "请选择加密方式：" "${ss_methods_list[@]}"
    local method_choice=$?
    
    if [[ $method_choice -eq 0 ]]; then
        return 0
    fi
    
    local ss_method="${ss_methods_list[$((method_choice-1))]}"
    
    # 创建配置文件
    mkdir -p /etc/shadowsocks-libev
    cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server": "0.0.0.0",
    "server_port": $ss_port,
    "password": "$ss_password",
    "timeout": 300,
    "method": "$ss_method",
    "fast_open": false
}
EOF
    
    # 启动服务
    systemctl enable shadowsocks-libev
    systemctl start shadowsocks-libev
    
    if systemctl is-active shadowsocks-libev >/dev/null 2>&1; then
        print_success "Shadowsocks服务启动成功"
        print_info "连接信息："
        echo "  服务器: $(curl -s ipv4.icanhazip.com 2>/dev/null || echo "您的服务器IP")"
        echo "  端口: $ss_port"
        echo "  密码: $ss_password"
        echo "  加密: $ss_method"
    else
        print_error "Shadowsocks服务启动失败"
    fi
}

# 使用脚本安装Shadowsocks
install_shadowsocks_script() {
    print_info "使用一键脚本安装Shadowsocks..."
    
    if bash <(curl -sL https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev.sh) 2>/dev/null; then
        print_success "Shadowsocks安装完成"
    else
        print_error "Shadowsocks安装失败"
    fi
}

# 部署WireGuard VPN
deploy_wireguard_vpn() {
    clear
    print_header "WireGuard VPN 部署"
    
    print_info "WireGuard是一个现代化的VPN协议"
    
    if ! check_network; then
        print_error "网络连接失败"
        return 1
    fi
    
    if command_exists wg; then
        print_warning "WireGuard已安装"
        return 0
    fi
    
    if ! confirm_action "确定要安装WireGuard VPN吗？"; then
        return 0
    fi
    
    # 安装WireGuard
    case $PACKAGE_MANAGER in
        apt)
            package_install wireguard
            ;;
        yum|dnf)
            package_install epel-release
            package_install wireguard-tools
            ;;
        pacman)
            package_install wireguard-tools
            ;;
        *)
            print_error "不支持的包管理器"
            return 1
            ;;
    esac
    
    if command_exists wg; then
        print_success "WireGuard安装成功"
        configure_wireguard
    else
        print_error "WireGuard安装失败"
    fi
}

# 配置WireGuard
configure_wireguard() {
    print_info "配置WireGuard VPN..."
    
    # 生成密钥
    local server_private_key=$(wg genkey)
    local server_public_key=$(echo "$server_private_key" | wg pubkey)
    local client_private_key=$(wg genkey)
    local client_public_key=$(echo "$client_private_key" | wg pubkey)
    
    print_prompt "请输入VPN网段 [10.0.0.0/24]: "
    read -r vpn_network
    vpn_network=${vpn_network:-10.0.0.0/24}
    
    print_prompt "请输入监听端口 [51820]: "
    read -r wg_port
    wg_port=${wg_port:-51820}
    
    # 创建服务器配置
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $server_private_key
Address = 10.0.0.1/24
ListenPort = $wg_port
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $client_public_key
AllowedIPs = 10.0.0.2/32
EOF
    
    # 创建客户端配置
    cat > /root/client.conf << EOF
[Interface]
PrivateKey = $client_private_key
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $server_public_key
Endpoint = $(curl -s ipv4.icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP"):$wg_port
AllowedIPs = 0.0.0.0/0
EOF
    
    # 启用IP转发
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    sysctl -p
    
    # 启动WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    if systemctl is-active wg-quick@wg0 >/dev/null 2>&1; then
        print_success "WireGuard VPN启动成功"
        print_info "客户端配置文件已生成: /root/client.conf"
    else
        print_error "WireGuard VPN启动失败"
    fi
}

# 部署OpenVPN服务器
deploy_openvpn_server() {
    clear
    print_header "OpenVPN 服务器部署"
    
    print_info "OpenVPN是一个成熟的VPN解决方案"
    
    if ! check_network; then
        print_error "网络连接失败"
        return 1
    fi
    
    if command_exists openvpn; then
        print_warning "OpenVPN已安装"
        return 0
    fi
    
    if ! confirm_action "确定要安装OpenVPN服务器吗？"; then
        return 0
    fi
    
    print_info "使用OpenVPN一键安装脚本..."
    
    # 使用Nyr的OpenVPN安装脚本
    if wget https://git.io/vpn -O openvpn-install.sh 2>/dev/null; then
        chmod +x openvpn-install.sh
        ./openvpn-install.sh
        print_success "OpenVPN安装完成"
    else
        print_error "OpenVPN脚本下载失败"
    fi
}

# 节点管理菜单
node_management_menu() {
    while true; do
        clear
        print_header "节点管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看已安装的节点"
        print_menu_item "2" "启动/停止服务"
        print_menu_item "3" "查看服务状态"
        print_menu_item "4" "查看服务日志"
        print_menu_item "5" "卸载节点服务"
        print_menu_item "6" "备份配置"
        print_menu_item "7" "恢复配置"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-7]: "
        read -r choice
        
        case $choice in
            1) show_installed_nodes ;;
            2) manage_node_service ;;
            3) show_node_status ;;
            4) show_node_logs ;;
            5) uninstall_node ;;
            6) backup_node_config ;;
            7) restore_node_config ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 查看已安装的节点
show_installed_nodes() {
    print_header "已安装的节点服务"
    
    local found_nodes=false
    
    # 检查各种节点服务
    echo -e "${CYAN}◆ 代理节点${NC}"
    
    if command_exists v2ray; then
        echo "  ✓ V2Ray - $(systemctl is-active v2ray 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if command_exists xray; then
        echo "  ✓ Xray - $(systemctl is-active xray 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if command_exists x-ui; then
        echo "  ✓ 3X-UI Panel - $(systemctl is-active x-ui 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if systemctl list-unit-files | grep -q "snell.service"; then
        echo "  ✓ Snell - $(systemctl is-active snell 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if command_exists trojan; then
        echo "  ✓ Trojan - $(systemctl is-active trojan 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if systemctl list-unit-files | grep -q "shadowsocks"; then
        echo "  ✓ Shadowsocks - $(systemctl is-active shadowsocks-libev 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    echo ""
    echo -e "${CYAN}◆ VPN服务${NC}"
    
    if command_exists wg; then
        echo "  ✓ WireGuard - $(systemctl is-active wg-quick@wg0 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if command_exists openvpn; then
        echo "  ✓ OpenVPN - $(systemctl is-active openvpn 2>/dev/null || echo "未知状态")"
        found_nodes=true
    fi
    
    if [[ "$found_nodes" == "false" ]]; then
        print_info "未检测到已安装的节点服务"
    fi
}

# 管理节点服务
manage_node_service() {
    print_header "节点服务管理"
    
    local services=("v2ray" "xray" "x-ui" "snell" "trojan" "shadowsocks-libev" "wg-quick@wg0" "openvpn")
    local available_services=()
    
    # 检查可用的服务
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "${service%@*}"; then
            available_services+=("$service")
        fi
    done
    
    if [[ ${#available_services[@]} -eq 0 ]]; then
        print_info "未找到可查看日志的节点服务"
        return 0
    fi
    
    select_from_list "请选择要查看日志的服务：" "${available_services[@]}"
    local choice=$?
    
    if [[ $choice -eq 0 ]]; then
        return 0
    fi
    
    local selected_service="${available_services[$((choice-1))]}"
    
    print_info "显示 $selected_service 的最近日志 (按q退出):"
    journalctl -u "$selected_service" -f --no-pager
}

# 卸载节点
uninstall_node() {
    print_header "卸载节点服务"
    
    local nodes=("V2Ray" "Xray" "3X-UI" "Snell" "Trojan" "Shadowsocks" "WireGuard" "OpenVPN")
    local available_nodes=()
    
    # 检查已安装的节点
    command_exists v2ray && available_nodes+=("V2Ray")
    command_exists xray && available_nodes+=("Xray")
    command_exists x-ui && available_nodes+=("3X-UI")
    systemctl list-unit-files | grep -q "snell.service" && available_nodes+=("Snell")
    command_exists trojan && available_nodes+=("Trojan")
    systemctl list-unit-files | grep -q "shadowsocks" && available_nodes+=("Shadowsocks")
    command_exists wg && available_nodes+=("WireGuard")
    command_exists openvpn && available_nodes+=("OpenVPN")
    
    if [[ ${#available_nodes[@]} -eq 0 ]]; then
        print_info "未找到可卸载的节点服务"
        return 0
    fi
    
    select_from_list "请选择要卸载的节点：" "${available_nodes[@]}"
    local choice=$?
    
    if [[ $choice -eq 0 ]]; then
        return 0
    fi
    
    local selected_node="${available_nodes[$((choice-1))]}"
    
    if ! confirm_action "确定要卸载 $selected_node 吗？这将删除所有相关配置"; then
        return 0
    fi
    
    case $selected_node in
        "V2Ray")
            systemctl stop v2ray 2>/dev/null
            systemctl disable v2ray 2>/dev/null
            package_remove v2ray
            rm -rf /usr/local/etc/v2ray
            rm -rf /var/log/v2ray
            ;;
        "Xray")
            systemctl stop xray 2>/dev/null
            systemctl disable xray 2>/dev/null
            package_remove xray
            rm -rf /usr/local/etc/xray
            rm -rf /var/log/xray
            ;;
        "3X-UI")
            systemctl stop x-ui 2>/dev/null
            systemctl disable x-ui 2>/dev/null
            rm -rf /etc/x-ui
            rm -rf /usr/local/x-ui
            ;;
        "Snell")
            systemctl stop snell 2>/dev/null
            systemctl disable snell 2>/dev/null
            rm -rf /etc/snell
            rm -f /etc/systemd/system/snell.service
            ;;
        "Trojan")
            systemctl stop trojan 2>/dev/null
            systemctl disable trojan 2>/dev/null
            package_remove trojan
            rm -rf /etc/trojan
            ;;
        "Shadowsocks")
            systemctl stop shadowsocks-libev 2>/dev/null
            systemctl disable shadowsocks-libev 2>/dev/null
            package_remove shadowsocks-libev
            rm -rf /etc/shadowsocks-libev
            ;;
        "WireGuard")
            systemctl stop wg-quick@wg0 2>/dev/null
            systemctl disable wg-quick@wg0 2>/dev/null
            package_remove wireguard wireguard-tools
            rm -rf /etc/wireguard
            ;;
        "OpenVPN")
            systemctl stop openvpn 2>/dev/null
            systemctl disable openvpn 2>/dev/null
            package_remove openvpn
            rm -rf /etc/openvpn
            ;;
    esac
    
    print_success "$selected_node 已卸载"
}

# 备份配置
backup_node_config() {
    print_header "备份节点配置"
    
    local backup_dir="/root/node_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_info "创建备份目录: $backup_dir"
    
    # 备份各种配置文件
    local backup_paths=(
        "/etc/v2ray"
        "/usr/local/etc/v2ray"
        "/etc/xray"
        "/usr/local/etc/xray"
        "/etc/x-ui"
        "/etc/snell"
        "/etc/trojan"
        "/etc/shadowsocks-libev"
        "/etc/wireguard"
        "/etc/openvpn"
    )
    
    local backed_up=false
    
    for path in "${backup_paths[@]}"; do
        if [[ -d "$path" ]]; then
            cp -r "$path" "$backup_dir/" 2>/dev/null
            print_success "已备份: $path"
            backed_up=true
        fi
    done
    
    # 备份systemd服务文件
    local service_files=(
        "/etc/systemd/system/v2ray.service"
        "/etc/systemd/system/xray.service"
        "/etc/systemd/system/x-ui.service"
        "/etc/systemd/system/snell.service"
        "/etc/systemd/system/trojan.service"
    )
    
    mkdir -p "$backup_dir/systemd"
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            cp "$service_file" "$backup_dir/systemd/" 2>/dev/null
            print_success "已备份: $service_file"
            backed_up=true
        fi
    done
    
    if [[ "$backed_up" == "true" ]]; then
        # 创建备份信息文件
        cat > "$backup_dir/backup_info.txt" << EOF
备份创建时间: $(date)
备份创建者: $(whoami)
系统信息: $(uname -a)
备份内容: 节点配置文件和服务文件
EOF
        
        print_success "配置备份完成: $backup_dir"
        
        # 创建压缩包
        if command_exists tar; then
            tar -czf "${backup_dir}.tar.gz" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
            print_success "已创建压缩备份: ${backup_dir}.tar.gz"
        fi
    else
        print_warning "未找到可备份的配置文件"
        rmdir "$backup_dir" 2>/dev/null
    fi
}

# 恢复配置
restore_node_config() {
    print_header "恢复节点配置"
    
    # 查找备份文件
    local backup_files=($(find /root -name "node_backup_*.tar.gz" 2>/dev/null))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        print_warning "未找到备份文件"
        print_prompt "请输入备份文件路径: "
        read -r backup_path
        
        if [[ ! -f "$backup_path" ]]; then
            print_error "备份文件不存在"
            return 1
        fi
        
        backup_files=("$backup_path")
    fi
    
    # 让用户选择备份文件
    local backup_names=()
    for file in "${backup_files[@]}"; do
        backup_names+=("$(basename "$file")")
    done
    
    select_from_list "请选择要恢复的备份：" "${backup_names[@]}"
    local choice=$?
    
    if [[ $choice -eq 0 ]]; then
        return 0
    fi
    
    local selected_backup="${backup_files[$((choice-1))]}"
    
    if ! confirm_action "确定要恢复备份 $(basename "$selected_backup") 吗？这将覆盖现有配置"; then
        return 0
    fi
    
    # 解压备份
    local temp_dir="/tmp/restore_$(date +%s)"
    mkdir -p "$temp_dir"
    
    if tar -xzf "$selected_backup" -C "$temp_dir"; then
        print_success "备份文件解压成功"
        
        # 查找解压后的目录
        local restore_dir=$(find "$temp_dir" -type d -name "node_backup_*" | head -1)
        
        if [[ -d "$restore_dir" ]]; then
            # 恢复配置文件
            for config_dir in "$restore_dir"/*; do
                if [[ -d "$config_dir" && "$(basename "$config_dir")" != "systemd" ]]; then
                    local target_dir="/etc/$(basename "$config_dir")"
                    if [[ "$(basename "$config_dir")" == "v2ray" || "$(basename "$config_dir")" == "xray" ]]; then
                        target_dir="/usr/local/etc/$(basename "$config_dir")"
                    fi
                    
                    # 备份现有配置
                    if [[ -d "$target_dir" ]]; then
                        mv "$target_dir" "${target_dir}.backup.$(date +%s)" 2>/dev/null
                    fi
                    
                    # 恢复配置
                    cp -r "$config_dir" "$target_dir"
                    print_success "已恢复: $target_dir"
                fi
            done
            
            # 恢复systemd服务文件
            if [[ -d "$restore_dir/systemd" ]]; then
                cp "$restore_dir/systemd"/* /etc/systemd/system/ 2>/dev/null
                systemctl daemon-reload
                print_success "已恢复systemd服务文件"
            fi
            
            print_success "配置恢复完成"
            print_info "请重启相关服务使配置生效"
        else
            print_error "备份文件格式错误"
        fi
    else
        print_error "备份文件解压失败"
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
}; then
        print_info "未找到可管理的节点服务"
        return 0
    fi
    
    select_from_list "请选择要管理的服务：" "${available_services[@]}"
    local choice=$?
    
    if [[ $choice -eq 0 ]]; then
        return 0
    fi
    
    local selected_service="${available_services[$((choice-1))]}"
    
    local actions=("启动" "停止" "重启" "查看状态")
    select_from_list "请选择操作：" "${actions[@]}"
    local action_choice=$?
    
    case $action_choice in
        0) return ;;
        1)
            systemctl start "$selected_service"
            print_success "服务 $selected_service 已启动"
            ;;
        2)
            systemctl stop "$selected_service"
            print_success "服务 $selected_service 已停止"
            ;;
        3)
            systemctl restart "$selected_service"
            print_success "服务 $selected_service 已重启"
            ;;
        4)
            systemctl status "$selected_service" --no-pager
            ;;
    esac
}

# 查看节点状态
show_node_status() {
    print_header "节点服务状态"
    
    local services=("v2ray" "xray" "x-ui" "snell" "trojan" "shadowsocks-libev" "wg-quick@wg0" "openvpn")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "${service%@*}"; then
            echo -e "${CYAN}◆ $service${NC}"
            systemctl status "$service" --no-pager -l | head -10
            echo ""
        fi
    done
}

# 查看节点日志
show_node_logs() {
    print_header "节点服务日志"
    
    local services=("v2ray" "xray" "x-ui" "snell" "trojan" "shadowsocks-libev" "wg-quick@wg0" "openvpn")
    local available_services=()
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "${service%@*}"; then
            available_services+=("$service")
        fi
    done
    
    if [[ ${#available_services[@]} -eq 0 ]
