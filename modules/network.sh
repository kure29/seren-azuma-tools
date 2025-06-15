local test_hosts=("8.8.8.8" "1.1.1.1" "114.114.114.114" "baidu.com" "google.com")
    
    print_info "测试网络连通性..."
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            print_success "✓ $host - 连通"
        else
            print_error "✗ $host - 不通"
        fi
    done
}

# 网络配置
network_configuration() {
    while true; do
        clear
        print_header "网络配置"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看网络配置"
        print_menu_item "2" "配置静态IP"
        print_menu_item "3" "配置DHCP"
        print_menu_item "4" "修改主机名"
        print_menu_item "5" "配置网络别名"
        print_menu_item "6" "重启网络服务"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) show_network_config ;;
            2) configure_static_ip ;;
            3) configure_dhcp ;;
            4) change_hostname ;;
            5) configure_network_alias ;;
            6) restart_network ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 查看网络配置
show_network_config() {
    print_info "当前网络配置:"
    
    echo -e "${CYAN}◆ 网络接口${NC}"
    if command_exists ip; then
        ip addr show
    else
        ifconfig -a
    fi
    
    echo ""
    echo -e "${CYAN}◆ 路由信息${NC}"
    if command_exists ip; then
        ip route show
    else
        route -n
    fi
    
    echo ""
    echo -e "${CYAN}◆ DNS配置${NC}"
    cat /etc/resolv.conf 2>/dev/null || echo "无法读取DNS配置"
    
    echo ""
    echo -e "${CYAN}◆ 主机名${NC}"
    hostname
}

# 配置静态IP
configure_static_ip() {
    print_header "配置静态IP"
    
    # 显示当前网络接口
    print_info "当前网络接口:"
    if command_exists ip; then
        ip link show | grep -E "^[0-9]" | awk -F': ' '{print $2}'
    else
        ifconfig -a | grep -E "^[a-z]" | awk '{print $1}' | sed 's/://'
    fi
    
    print_prompt "请输入网络接口名 (如 eth0): "
    read -r interface
    print_prompt "请输入IP地址: "
    read -r ip_addr
    print_prompt "请输入子网掩码 [255.255.255.0]: "
    read -r netmask
    netmask=${netmask:-255.255.255.0}
    print_prompt "请输入网关地址: "
    read -r gateway
    print_prompt "请输入DNS服务器 [8.8.8.8]: "
    read -r dns
    dns=${dns:-8.8.8.8}
    
    if [[ -z "$interface" || -z "$ip_addr" || -z "$gateway" ]]; then
        print_error "接口名、IP地址和网关不能为空"
        return 1
    fi
    
    # 根据系统类型配置网络
    case $DISTRO in
        ubuntu|debian)
            configure_static_ip_debian "$interface" "$ip_addr" "$netmask" "$gateway" "$dns"
            ;;
        centos|rhel|rocky|almalinux|fedora)
            configure_static_ip_rhel "$interface" "$ip_addr" "$netmask" "$gateway" "$dns"
            ;;
        *)
            print_warning "不支持的系统类型，请手动配置"
            ;;
    esac
}

# Debian/Ubuntu静态IP配置
configure_static_ip_debian() {
    local interface=$1 ip_addr=$2 netmask=$3 gateway=$4 dns=$5
    
    # 备份配置文件
    if [[ -f /etc/netplan/50-cloud-init.yaml ]]; then
        cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
        # Netplan配置
        cat > /etc/netplan/50-cloud-init.yaml << EOF
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: false
      addresses: [$ip_addr/24]
      gateway4: $gateway
      nameservers:
        addresses: [$dns]
EOF
        netplan apply
    else
        # 传统网络配置
        cp /etc/network/interfaces /etc/network/interfaces.bak 2>/dev/null || true
        cat >> /etc/network/interfaces << EOF

auto $interface
iface $interface inet static
address $ip_addr
netmask $netmask
gateway $gateway
dns-nameservers $dns
EOF
    fi
    
    print_success "静态IP配置完成"
}

# RHEL/CentOS静态IP配置
configure_static_ip_rhel() {
    local interface=$1 ip_addr=$2 netmask=$3 gateway=$4 dns=$5
    
    local config_file="/etc/sysconfig/network-scripts/ifcfg-$interface"
    
    # 备份配置文件
    [[ -f "$config_file" ]] && cp "$config_file" "$config_file.bak"
    
    # 创建网络配置文件
    cat > "$config_file" << EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=$interface
DEVICE=$interface
ONBOOT=yes
IPADDR=$ip_addr
NETMASK=$netmask
GATEWAY=$gateway
DNS1=$dns
EOF
    
    print_success "静态IP配置完成"
}

# 配置DHCP
configure_dhcp() {
    print_header "配置DHCP"
    
    print_prompt "请输入网络接口名 (如 eth0): "
    read -r interface
    
    if [[ -z "$interface" ]]; then
        print_error "接口名不能为空"
        return 1
    fi
    
    case $DISTRO in
        ubuntu|debian)
            configure_dhcp_debian "$interface"
            ;;
        centos|rhel|rocky|almalinux|fedora)
            configure_dhcp_rhel "$interface"
            ;;
        *)
            print_warning "不支持的系统类型"
            ;;
    esac
}

# Debian/Ubuntu DHCP配置
configure_dhcp_debian() {
    local interface=$1
    
    if [[ -f /etc/netplan/50-cloud-init.yaml ]]; then
        cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
        cat > /etc/netplan/50-cloud-init.yaml << EOF
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: true
EOF
        netplan apply
    else
        cp /etc/network/interfaces /etc/network/interfaces.bak 2>/dev/null || true
        cat >> /etc/network/interfaces << EOF

auto $interface
iface $interface inet dhcp
EOF
    fi
    
    print_success "DHCP配置完成"
}

# RHEL/CentOS DHCP配置
configure_dhcp_rhel() {
    local interface=$1
    local config_file="/etc/sysconfig/network-scripts/ifcfg-$interface"
    
    [[ -f "$config_file" ]] && cp "$config_file" "$config_file.bak"
    
    cat > "$config_file" << EOF
TYPE=Ethernet
BOOTPROTO=dhcp
NAME=$interface
DEVICE=$interface
ONBOOT=yes
EOF
    
    print_success "DHCP配置完成"
}

# 修改主机名
change_hostname() {
    print_header "修改主机名"
    
    print_info "当前主机名: $(hostname)"
    print_prompt "请输入新的主机名: "
    read -r new_hostname
    
    if [[ -z "$new_hostname" ]]; then
        print_error "主机名不能为空"
        return 1
    fi
    
    # 验证主机名格式
    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        print_error "主机名只能包含字母、数字和连字符"
        return 1
    fi
    
    if confirm_action "确定要将主机名改为 $new_hostname 吗？"; then
        # 设置主机名
        if command_exists hostnamectl; then
            hostnamectl set-hostname "$new_hostname"
        else
            hostname "$new_hostname"
            echo "$new_hostname" > /etc/hostname
        fi
        
        # 更新hosts文件
        sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
        
        print_success "主机名已修改为: $new_hostname"
        print_info "重启后生效，当前会话中立即生效"
    fi
}

# 配置网络别名
configure_network_alias() {
    print_header "配置网络别名"
    
    print_prompt "请输入网络接口名 (如 eth0): "
    read -r interface
    print_prompt "请输入别名编号 (如 0): "
    read -r alias_num
    print_prompt "请输入别名IP地址: "
    read -r alias_ip
    print_prompt "请输入子网掩码 [255.255.255.0]: "
    read -r netmask
    netmask=${netmask:-255.255.255.0}
    
    if [[ -z "$interface" || -z "$alias_num" || -z "$alias_ip" ]]; then
        print_error "接口名、别名编号和IP地址不能为空"
        return 1
    fi
    
    local alias_interface="${interface}:${alias_num}"
    
    # 临时配置
    if command_exists ip; then
        ip addr add "$alias_ip/24" dev "$interface" label "$alias_interface"
    else
        ifconfig "$alias_interface" "$alias_ip" netmask "$netmask"
    fi
    
    print_success "网络别名 $alias_interface ($alias_ip) 配置完成"
    print_warning "这是临时配置，重启后失效"
}

# 重启网络服务
restart_network() {
    print_header "重启网络服务"
    
    if ! confirm_action "确定要重启网络服务吗？这可能导致连接中断"; then
        return 0
    fi
    
    print_info "重启网络服务..."
    
    case $DISTRO in
        ubuntu|debian)
            if command_exists netplan; then
                netplan apply
            elif systemctl is-active networking >/dev/null 2>&1; then
                systemctl restart networking
            else
                /etc/init.d/networking restart
            fi
            ;;
        centos|rhel|rocky|almalinux|fedora)
            if systemctl is-active NetworkManager >/dev/null 2>&1; then
                systemctl restart NetworkManager
            else
                systemctl restart network
            fi
            ;;
        *)
            print_warning "请手动重启网络服务"
            ;;
    esac
    
    print_success "网络服务重启完成"
}

# 带宽测试
bandwidth_test() {
    while true; do
        clear
        print_header "带宽测试"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "安装speedtest-cli"
        print_menu_item "2" "运行速度测试"
        print_menu_item "3" "iperf3测试"
        print_menu_item "4" "本地网络测试"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-4]: "
        read -r choice
        
        case $choice in
            1) install_speedtest ;;
            2) run_speedtest ;;
            3) iperf3_test ;;
            4) local_network_test ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 安装speedtest-cli
install_speedtest() {
    print_header "安装speedtest-cli"
    
    if command_exists speedtest-cli; then
        print_warning "speedtest-cli已安装"
        return 0
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            package_install speedtest-cli
            ;;
        yum|dnf)
            package_install python3-pip
            pip3 install speedtest-cli
            ;;
        pacman)
            package_install speedtest-cli
            ;;
        zypper)
            package_install python3-speedtest-cli
            ;;
        *)
            print_info "尝试使用pip安装..."
            if command_exists pip3; then
                pip3 install speedtest-cli
            elif command_exists pip; then
                pip install speedtest-cli
            else
                print_error "无法安装speedtest-cli"
                return 1
            fi
            ;;
    esac
    
    if command_exists speedtest-cli; then
        print_success "speedtest-cli安装成功"
    else
        print_error "speedtest-cli安装失败"
    fi
}

# 运行速度测试
run_speedtest() {
    if ! command_exists speedtest-cli; then
        print_error "speedtest-cli未安装，请先安装"
        return 1
    fi
    
    print_info "正在运行网络速度测试..."
    print_warning "测试可能需要几分钟时间"
    
    speedtest-cli
}

# iperf3测试
iperf3_test() {
    if ! command_exists iperf3; then
        print_warning "iperf3未安装"
        if confirm_action "是否安装iperf3？"; then
            package_install iperf3
        else
            return 0
        fi
    fi
    
    print_info "iperf3网络性能测试"
    local modes=("作为客户端测试" "作为服务器运行")
    select_from_list "请选择模式：" "${modes[@]}"
    local choice=$?
    
    case $choice in
        0) return ;;
        1)
            print_prompt "请输入服务器地址: "
            read -r server
            if [[ -n "$server" ]]; then
                iperf3 -c "$server"
            fi
            ;;
        2)
            print_info "启动iperf3服务器模式..."
            print_info "其他客户端可使用以下命令连接:"
            echo "iperf3 -c $(hostname -I | awk '{print $1}')"
            iperf3 -s
            ;;
    esac
}

# 本地网络测试
local_network_test() {
    print_header "本地网络测试"
    
    print_info "测试本地网络接口性能..."
    
    # 网络接口统计
    if command_exists ip; then
        echo -e "${CYAN}◆ 网络接口统计${NC}"
        ip -s link
    fi
    
    # 网络延迟测试
    echo ""
    echo -e "${CYAN}◆ 本地回环测试${NC}"
    ping -c 5 127.0.0.1
    
    # 如果有多个接口，测试接口间通信
    echo ""
    echo -e "${CYAN}◆ 接口列表${NC}"
    if command_exists ip; then
        ip addr show | grep "inet " | awk '{print $2}' | grep -v "127.0.0.1"
    fi
}

# 端口扫描
port_scan() {
    while true; do
        clear
        print_header "端口扫描"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "扫描本机开放端口"
        print_menu_item "2" "扫描远程主机端口"
        print_menu_item "3" "检查特定端口"
        print_menu_item "4" "常用端口扫描"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-4]: "
        read -r choice
        
        case $choice in
            1) scan_local_ports ;;
            2) scan_remote_ports ;;
            3) check_specific_port ;;
            4) scan_common_ports ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 扫描本机开放端口
scan_local_ports() {
    print_info "扫描本机开放端口..."
    
    if command_exists ss; then
        echo "TCP端口:"
        ss -tuln | grep LISTEN
    elif command_exists netstat; then
        echo "TCP端口:"
        netstat -tuln | grep LISTEN
    else
        print_warning "未找到端口扫描工具"
    fi
}

# 扫描远程主机端口
scan_remote_ports() {
    print_prompt "请输入要扫描的主机: "
    read -r target_host
    print_prompt "请输入端口范围 (如 1-1000): "
    read -r port_range
    
    if [[ -z "$target_host" || -z "$port_range" ]]; then
        print_error "主机和端口范围不能为空"
        return 1
    fi
    
    if command_exists nmap; then
        print_info "使用nmap扫描 $target_host 端口 $port_range..."
        nmap -p "$port_range" "$target_host"
    else
        print_warning "nmap未安装，请安装后使用"
        print_info "安装命令："
        case $PACKAGE_MANAGER in
            apt) echo "apt install nmap" ;;
            yum|dnf) echo "$PACKAGE_MANAGER install nmap" ;;
            pacman) echo "pacman -S nmap" ;;
            zypper) echo "zypper install nmap" ;;
        esac
    fi
}

# 检查特定端口
check_specific_port() {
    print_prompt "请输入主机地址 [localhost]: "
    read -r host
    host=${host:-localhost}
    print_prompt "请输入端口号: "
    read -r port
    
    if [[ -z "$port" ]]; then
        print_error "端口号不能为空"
        return 1
    fi
    
    print_info "检查 $host:$port..."
    
    # 使用nc或telnet检查端口
    if command_exists nc; then
        if nc -z -w3 "$host" "$port" 2>/dev/null; then
            print_success "端口 $port 开放"
        else
            print_error "端口 $port 关闭"
        fi
    elif command_exists telnet; then
        timeout 3 telnet "$host" "$port" 2>/dev/null && print_success "端口 $port 开放" || print_error "端口 $port 关闭"
    else
        print_warning "未找到端口检查工具"
    fi
}

# 扫描常用端口
scan_common_ports() {
    print_prompt "请输入要扫描的主机 [localhost]: "
    read -r target_host
    target_host=${target_host:-localhost}
    
    local common_ports=(22 23 25 53 80 110 143 443 993 995 3389 5432 3306)
    
    print_info "扫描 $target_host 的常用端口..."
    
    for port in "${common_ports[@]}"; do
        if command_exists nc; then
            if nc -z -w1 "$target_host" "$port" 2>/dev/null; then
                print_success "端口 $port 开放"
            fi
        fi
    done
}

# 网络监控
network_monitor() {
    while true; do
        clear
        print_header "网络监控"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "实时网络流量"
        print_menu_item "2" "网络连接监控"
        print_menu_item "3" "带宽使用统计"
        print_menu_item "4" "网络错误统计"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-4]: "
        read -r choice
        
        case $choice in
            1) real_time_traffic ;;
            2) connection_monitor ;;
            3) bandwidth_statistics ;;
            4) network_error_stats ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 实时网络流量
real_time_traffic() {
    if command_exists iftop; then
        print_info "启动iftop实时监控 (按q退出)..."
        iftop
    elif command_exists nethogs; then
        print_info "启动nethogs实时监控 (按q退出)..."
        nethogs
    else
        print_warning "未安装网络监控工具"
        print_info "可安装以下工具："
        echo "  iftop: 显示网络连接流量"
        echo "  nethogs: 按进程显示网络使用"
        case $PACKAGE_MANAGER in
            apt) echo "  安装: apt install iftop nethogs" ;;
            yum|dnf) echo "  安装: $PACKAGE_MANAGER install iftop nethogs" ;;
            pacman) echo "  安装: pacman -S iftop nethogs" ;;
        esac
    fi
}

# 网络连接监控
connection_monitor() {
    print_info "网络连接监控 (每5秒刷新一次，按Ctrl+C退出)..."
    
    while true; do
        clear
        echo -e "${CYAN}$(date)${NC}"
        echo ""
        
        if command_exists ss; then
            echo "活跃连接数: $(ss -tun | wc -l)"
            echo ""
            echo "TCP连接状态统计:"
            ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr
            echo ""
            echo "监听端口:"
            ss -tuln | grep LISTEN
        else
            echo "活跃连接数: $(netstat -tun | wc -l)"
            echo ""
            echo "TCP连接状态统计:"
            netstat -tan | awk 'NR>2 {print $6}' | sort | uniq -c | sort -nr
        fi
        
        sleep 5
    done
}

# 带宽使用统计
bandwidth_statistics() {
    print_info "网络接口统计信息:"
    
    if command_exists ip; then
        ip -s link
    elif [[ -f /proc/net/dev ]]; then
        cat /proc/net/dev
    else
        print_warning "无法获取网络统计信息"
    fi
    
    echo ""
    print_info "详细统计 (RX=接收, TX=发送):"
    
    local interfaces=$(ip link show | grep -E "^[0-9]" | awk -F': ' '{print $2}' | grep -v lo)
    
    for interface in $interfaces; do
        if [[ -d "/sys/class/net/$interface/statistics" ]]; then
            local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
            local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
            local rx_packets=$(cat "/sys/class/net/$interface/statistics/rx_packets")
            local tx_packets=$(cat "/sys/class/net/$interface/statistics/tx_packets")
            
            echo "$interface:"
            echo "  RX: $(numfmt --to=iec "$rx_bytes")B ($rx_packets packets)"
            echo "  TX: $(numfmt --to=iec "$tx_bytes")B ($tx_packets packets)"
        fi
    done
}

# 网络错误统计
network_error_stats() {
    print_info "网络错误统计:"
    
    local interfaces=$(ip link show | grep -E "^[0-9]" | awk -F': ' '{print $2}' | grep -v lo)
    
    for interface in $interfaces; do
        if [[ -d "/sys/class/net/$interface/statistics" ]]; then
            local rx_errors=$(cat "/sys/class/net/$interface/statistics/rx_errors")
            local tx_errors=$(cat "/sys/class/net/$interface/statistics/tx_errors")
            local rx_dropped=$(cat "/sys/class/net/$interface/statistics/rx_dropped")
            local tx_dropped=$(cat "/sys/class/net/$interface/statistics/tx_dropped")
            
            echo "$interface 错误统计:"
            echo "  RX错误: $rx_errors, RX丢包: $rx_dropped"
            echo "  TX错误: $tx_errors, TX丢包: $tx_dropped"
            echo ""
        fi
    done
}

# DNS工具
dns_tools() {
    while true; do
        clear
        print_header "DNS工具"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "DNS查询"
        print_menu_item "2" "反向DNS查询"
        print_menu_item "3" "DNS性能测试"
        print_menu_item "4" "刷新DNS缓存"
        print_menu_item "5" "查看DNS配置"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1) dns_lookup ;;
            2) reverse_dns_lookup ;;
            3) dns_performance_test ;;
            4) flush_dns_cache ;;
            5) show_dns_config ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# DNS查询
dns_lookup() {
    print_prompt "请输入要查询的域名: "
    read -r domain
    
    if [[ -z "$domain" ]]; then
        print_error "域名不能为空"
        return 1
    fi
    
    print_info "查询域名: $domain"
    
    if command_exists dig; then
        dig "$domain"
        echo ""
        echo "简化输出:"
        dig +short "$domain"
    elif command_exists nslookup; then
        nslookup "$domain"
    else
        print_warning "未找到DNS查询工具"
    fi
}

# 反向DNS查询
reverse_dns_lookup() {
    print_prompt "请输入IP地址: "
    read -r ip_addr
    
    if [[ -z "$ip_addr" ]]; then
        print_error "IP地址不能为空"
        return 1
    fi
    
    print_info "反向查询IP: $ip_addr"
    
    if command_exists dig; then
        dig -x "$ip_addr"
    elif command_exists nslookup; then
        nslookup "$ip_addr"
    else
        print_warning "未找到DNS查询工具"
    fi
}

# DNS性能测试
dns_performance_test() {
    local dns_servers=("8.8.8.8" "1.1.1.1" "114.114.114.114" "223.5.5.5")
    local test_domain="google.com"
    
    print_info "测试DNS服务器性能 (查询 $test_domain)..."
    
    for dns in "${dns_servers[@]}"; do
        if command_exists dig; then
            local time=$(dig @"$dns" "$test_domain" | grep "Query time:" | awk '{print $4}')
            if [[ -n "$time" ]]; then
                echo "$dns: ${time}ms"
            else
                echo "$dns: 超时"
            fi
        else
            echo "$dns: 需要dig工具"
        fi
    done
}

# 刷新DNS缓存
flush_dns_cache() {
    print_info "刷新DNS缓存..."
    
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        systemctl flush-dns
        print_success "systemd-resolved DNS缓存已刷新"
    elif command_exists resolvectl; then
        resolvectl flush-caches
        print_success "DNS缓存已刷新"
    elif [[ -f /etc/init.d/nscd ]]; then
        /etc/init.d/nscd restart
        print_success "nscd DNS缓存已刷新"
    else
        print_warning "未找到DNS缓存服务"
    fi
}

# 查看DNS配置
show_dns_config() {
    print_info "DNS配置信息:"
    
    echo -e "${CYAN}◆ /etc/resolv.conf${NC}"
    cat /etc/resolv.conf 2>/dev/null || echo "无法读取resolv.conf"
    
    echo ""
    echo -e "${CYAN}◆ systemd-resolved配置${NC}"
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        resolvectl status 2>/dev/null || systemd-resolve --status 2>/dev/null || echo "无法获取systemd-resolved状态"
    else
        echo "systemd-resolved未运行"
    fi
    
    echo ""
    echo -e "${CYAN}◆ /etc/hosts${NC}"
    head -10 /etc/hosts 2>/dev/null || echo "无法读取hosts文件"
}#!/bin/bash

# 网络管理模块
# 作者: 東雪蓮 (Seren Azuma)

# 网络管理主菜单
network_management_menu() {
    while true; do
        clear
        print_header "网络管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "网络诊断"
        print_menu_item "2" "网络配置"
        print_menu_item "3" "带宽测试"
        print_menu_item "4" "端口扫描"
        print_menu_item "5" "网络监控"
        print_menu_item "6" "DNS工具"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-6]: "
        read -r choice
        
        case $choice in
            1) network_diagnostics ;;
            2) network_configuration ;;
            3) bandwidth_test ;;
            4) port_scan ;;
            5) network_monitor ;;
            6) dns_tools ;;
            0) return ;;
            *) print_error "无效的选择，请输入0-6之间的数字" ;;
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
        print_menu_item "2" "网络延迟测试"
        print_menu_item "3" "路由追踪"
        print_menu_item "4" "网卡状态"
        print_menu_item "5" "路由表"
        print_menu_item "6" "ARP表"
        print_menu_item "7" "网络连通性测试"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-7]: "
        read -r choice
        
        case $choice in
            1) show_network_connections ;;
            2) ping_test ;;
            3) traceroute_test ;;
            4) show_interface_status ;;
            5) show_routing_table ;;
            6) show_arp_table ;;
            7) connectivity_test ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 显示网络连接状态
show_network_connections() {
    print_info "网络连接状态:"
    
    if command_exists ss; then
        echo "TCP连接:"
        ss -tuln | head -20
        echo ""
        echo "连接统计:"
        ss -s
    elif command_exists netstat; then
        echo "TCP连接:"
        netstat -tuln | head -20
        echo ""
        echo "连接统计:"
        netstat -s | head -20
    else
        print_warning "未找到网络工具，请安装net-tools"
    fi
}

# 网络延迟测试
ping_test() {
    print_prompt "请输入要测试的主机 [8.8.8.8]: "
    read -r host
    host=${host:-8.8.8.8}
    
    print_prompt "请输入测试次数 [5]: "
    read -r count
    count=${count:-5}
    
    print_info "正在测试到 $host 的连通性..."
    ping -c "$count" "$host"
}

# 路由追踪
traceroute_test() {
    print_prompt "请输入要追踪的主机 [8.8.8.8]: "
    read -r host
    host=${host:-8.8.8.8}
    
    print_info "正在追踪到 $host 的路由..."
    
    if command_exists traceroute; then
        traceroute "$host"
    elif command_exists tracepath; then
        tracepath "$host"
    else
        print_warning "未找到traceroute工具，请安装"
        case $PACKAGE_MANAGER in
            apt) print_info "安装命令: apt install traceroute" ;;
            yum|dnf) print_info "安装命令: $PACKAGE_MANAGER install traceroute" ;;
            pacman) print_info "安装命令: pacman -S traceroute" ;;
            zypper) print_info "安装命令: zypper install traceroute" ;;
        esac
    fi
}

# 显示网卡状态
show_interface_status() {
    print_info "网络接口状态:"
    
    if command_exists ip; then
        ip addr show
        echo ""
        echo "网络接口统计:"
        ip -s link
    elif command_exists ifconfig; then
        ifconfig -a
    else
        print_warning "未找到网络配置工具"
    fi
}

# 显示路由表
show_routing_table() {
    print_info "路由表:"
    
    if command_exists ip; then
        ip route show
    elif command_exists route; then
        route -n
    else
        print_warning "未找到路由工具"
    fi
}

# 显示ARP表
show_arp_table() {
    print_info "ARP表:"
    
    if command_exists ip; then
        ip neigh show
    elif command_exists arp; then
        arp -a
    else
        print_warning "未找到ARP工具"
    fi
}

# 网络连通性测试
connectivity_test() {
    print_header "网络连通性测试"
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "114.114.114.114" "baidu.com" "google
