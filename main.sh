#!/bin/bash

# Seren Azuma 系统管理脚本 - 主入口
# 版本: 3.0 (模块化版本)
# 作者: 東雪蓮 (Seren Azuma)

# 脚本目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# 加载配置
source "$SCRIPT_DIR/config/config.sh" || {
    echo "错误: 无法加载配置文件"
    exit 1
}

# 加载通用函数库
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "错误: 无法加载通用函数库"
    exit 1
}

source "$SCRIPT_DIR/lib/system.sh" || {
    echo "错误: 无法加载系统函数库"
    exit 1
}

source "$SCRIPT_DIR/lib/ui.sh" || {
    echo "错误: 无法加载UI函数库"
    exit 1
}

# 主函数
main() {
    # 初始化
    check_root
    detect_system
    init_logging
    
    # 检查并安装figlet以获得更好的显示效果
    check_figlet
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) 
                load_module "software"
                ;;
            2) 
                load_module "docker"
                ;;
            3) 
                load_module "system_mgmt"
                ;;
            4) 
                load_module "node_deploy"
                ;;
            9) 
                show_logs
                ;;
            0) 
                exit_script
                ;;
            *)
                print_error "无效的选择，请输入0-4或9"
                wait_for_key 1
                ;;
        esac
    done
}

# 动态加载模块
load_module() {
    local module_name=$1
    local module_file="$SCRIPT_DIR/modules/${module_name}.sh"
    
    if [[ -f "$module_file" ]]; then
        print_info "加载模块: $module_name"
        source "$module_file"
        # 调用模块的主菜单函数
        ${module_name}_menu
    else
        print_error "模块文件不存在: $module_file"
        print_warning "请检查安装是否完整"
        wait_for_key 1
    fi
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

# 运行主程序
main "$@"
