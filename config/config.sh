#!/bin/bash

# 系统管理脚本配置文件
# 作者: 東雪蓮 (Seren Azuma)

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
SCRIPT_DIR=${SCRIPT_DIR:-$(dirname "$(readlink -f "$0")")}
LOG_FILE="$SCRIPT_DIR/system_manager.log"
DISTRO=""
PACKAGE_MANAGER=""
SERVICE_MANAGER=""
FIREWALL_CMD=""

# 脚本信息
SCRIPT_NAME="Seren Azuma Linux Tools"
SCRIPT_VERSION="3.0"
SCRIPT_AUTHOR="東雪蓮 (Seren Azuma)"

# 网络测试主机列表
NETWORK_TEST_HOSTS=("8.8.8.8" "1.1.1.1" "114.114.114.114")

# DNS服务器配置
declare -A DNS_SERVERS=(
    ["阿里云"]="223.5.5.5,223.6.6.6"
    ["腾讯"]="119.29.29.29,182.254.116.116"
    ["百度"]="180.76.76.76,114.114.114.114"
    ["Google"]="8.8.8.8,8.8.4.4"
    ["Cloudflare"]="1.1.1.1,1.0.0.1"
    ["OpenDNS"]="208.67.222.222,208.67.220.220"
    ["Quad9"]="9.9.9.9,149.112.112.112"
)

# 常用时区配置
declare -A TIMEZONES=(
    ["中国"]="Asia/Shanghai"
    ["美东"]="America/New_York"
    ["美西"]="America/Los_Angeles"
    ["欧洲"]="Europe/Berlin"
    ["日本"]="Asia/Tokyo"
    ["UTC"]="UTC"
)

# 软件包配置
declare -A BASIC_TOOLS=(
    ["apt"]="curl wget unzip zip vim nano htop tree git figlet"
    ["yum"]="curl wget unzip zip vim nano htop tree git figlet"
    ["dnf"]="curl wget unzip zip vim nano htop tree git figlet"
    ["pacman"]="curl wget unzip zip vim nano htop tree git figlet"
    ["zypper"]="curl wget unzip zip vim nano htop tree git figlet"
    ["apk"]="curl wget unzip zip vim nano htop tree git figlet"
)

declare -A NETWORK_TOOLS=(
    ["apt"]="net-tools dnsutils traceroute nmap"
    ["yum"]="net-tools bind-utils traceroute nmap"
    ["dnf"]="net-tools bind-utils traceroute nmap"
    ["pacman"]="net-tools bind-tools traceroute nmap"
    ["zypper"]="net-tools bind-utils traceroute nmap"
    ["apk"]="net-tools bind-tools traceroute nmap"
)

declare -A DEV_TOOLS=(
    ["apt"]="build-essential software-properties-common"
    ["yum"]="gcc gcc-c++ make kernel-devel"
    ["dnf"]="gcc gcc-c++ make kernel-devel"
    ["pacman"]="base-devel"
    ["zypper"]="gcc gcc-c++ make kernel-default-devel"
    ["apk"]="build-base linux-headers"
)
