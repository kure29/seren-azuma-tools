#!/bin/bash

# 全局配置文件
# Seren Azuma 系统管理脚本配置

# 版本信息
SCRIPT_VERSION="3.0"
SCRIPT_AUTHOR="東雪蓮 (Seren Azuma)"

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

# 获取脚本根目录
SCRIPT_ROOT_DIR=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")

# 全局变量
LOG_FILE="$SCRIPT_ROOT_DIR/logs/system_manager.log"
TEMPLATE_DIR="$SCRIPT_ROOT_DIR/templates"
DISTRO=""
PACKAGE_MANAGER=""
SERVICE_MANAGER=""
FIREWALL_CMD=""

# 创建必要目录
mkdir -p "$SCRIPT_ROOT_DIR/logs"
mkdir -p "$SCRIPT_ROOT_DIR/templates"

# 网络测试主机列表
NETWORK_TEST_HOSTS=("8.8.8.8" "1.1.1.1" "114.114.114.114")

# 常用工具包定义
declare -A COMMON_TOOLS
COMMON_TOOLS[apt]="curl wget unzip zip vim nano htop tree git figlet net-tools dnsutils traceroute nmap build-essential"
COMMON_TOOLS[yum]="curl wget unzip zip vim nano htop tree git figlet net-tools bind-utils traceroute nmap gcc gcc-c++ make"
COMMON_TOOLS[dnf]="curl wget unzip zip vim nano htop tree git figlet net-tools bind-utils traceroute nmap gcc gcc-c++ make"
COMMON_TOOLS[pacman]="curl wget unzip zip vim nano htop tree git figlet net-tools bind-tools traceroute nmap base-devel"
COMMON_TOOLS[zypper]="curl wget unzip zip vim nano htop tree git figlet net-tools bind-utils traceroute nmap gcc gcc-c++ make"
COMMON_TOOLS[apk]="curl wget unzip zip vim nano htop tree git figlet net-tools bind-tools traceroute nmap build-base"

# DNS服务器配置
declare -A DNS_CONFIGS
DNS_CONFIGS[aliyun]="223.5.5.5,223.6.6.6"
DNS_CONFIGS[tencent]="119.29.29.29,182.254.116.116"
DNS_CONFIGS[baidu]="180.76.76.76,114.114.114.114"
DNS_CONFIGS[google]="8.8.8.8,8.8.4.4"
DNS_CONFIGS[cloudflare]="1.1.1.1,1.0.0.1"
DNS_CONFIGS[opendns]="208.67.222.222,208.67.220.220"
DNS_CONFIGS[quad9]="9.9.9.9,149.112.112.112"

# 时区配置
declare -A TIMEZONE_CONFIGS
TIMEZONE_CONFIGS[china]="Asia/Shanghai"
TIMEZONE_CONFIGS[us_east]="America/New_York"
TIMEZONE_CONFIGS[us_west]="America/Los_Angeles"
TIMEZONE_CONFIGS[europe]="Europe/Berlin"
TIMEZONE_CONFIGS[japan]="Asia/Tokyo"
TIMEZONE_CONFIGS[utc]="UTC"

# 节点部署脚本URL
SNELL_SCRIPT_URL="https://git.io/Snell.sh"
XRAY_3XUI_SCRIPT_URL="https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh"

# 日志级别
LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR

# 脚本运行环境检查
if [[ -z "$SCRIPT_ROOT_DIR" ]]; then
    echo "错误: 无法确定脚本根目录"
    exit 1
fi
