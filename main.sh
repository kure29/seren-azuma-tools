#!/bin/bash

# 通用Linux系统管理脚本 - 主入口
# 作者: 東雪蓮 (Seren Azuma)
# 版本: 3.0 (模块化版本)

# 获取脚本目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# 检查目录结构
if [[ ! -d "$SCRIPT_DIR/lib" ]] || [[ ! -d "$SCRIPT_DIR/modules" ]]; then
    echo "错误: 缺少必要的目录结构"
    echo "请确保存在 lib/ 和 modules/ 目录"
    exit 1
fi

# 加载配置和公共函数
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# 加载功能模块
source "$SCRIPT_DIR/modules/system.sh"
source "$SCRIPT_DIR/modules/software.sh"
source "$SCRIPT_DIR/modules/docker.sh"
source "$SCRIPT_DIR/modules/security.sh"
source "$SCRIPT_DIR/modules/network.sh"
source "$SCRIPT_DIR/modules/nodes.sh"

# 主程序入口
main() {
    # 初始化检查
    check_root
    detect_system
    init_logging
    
    log_message "脚本启动 - 系统: $(echo ${DISTRO^}), 包管理器: $PACKAGE_MANAGER"
    
    # 主循环
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) software_management_menu ;;
            2) docker_management_menu ;;
            3) system_management_menu ;;
            4) security_management_menu ;;
            5) network_management_menu ;;
            6) node_deployment_menu ;;
            9) show_system_logs ;;
            0) exit_script ;;
            *) 
                print_error "无效的选择，请输入0-6或9"
                wait_for_key 1
                ;;
        esac
    done
}

# 退出脚本
exit_script() {
    print_info "感谢使用 Seren Azuma 系统管理脚本"
    log_message "脚本退出"
    exit 0
}

# 显示系统日志
show_system_logs() {
    echo ""
    print_info "显示最近的操作日志："
    if [[ -f "$LOG_FILE" ]]; then
        tail -20 "$LOG_FILE"
    else
        print_warning "日志文件不存在"
    fi
    wait_for_key 1
}

# 运行主程序
main "$@"
