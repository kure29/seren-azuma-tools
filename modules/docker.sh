#!/bin/bash

# Docker管理模块
# 作者: 東雪蓮 (Seren Azuma)

# Docker管理主菜单
docker_management_menu() {
    while true; do
        clear
        print_header "Docker管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "安装Docker"
        print_menu_item "2" "卸载Docker"
        print_menu_item "3" "查看Docker状态"
        print_menu_item "4" "Docker容器管理"
        print_menu_item "5" "Docker镜像管理"
        print_menu_item "6" "Docker网络管理"
        print_menu_item "7" "Docker存储管理"
        print_menu_item "8" "Docker Compose管理"
        print_menu_item "0" "返回主菜单"
        
        print_prompt "请选择操作 [0-8]: "
        read -r choice
        
        case $choice in
            1)
                echo ""
                check_network && install_docker
                ;;
            2)
                echo ""
                uninstall_docker
                ;;
            3)
                echo ""
                show_docker_status
                ;;
            4)
                echo ""
                docker_container_menu
                ;;
            5)
                echo ""
                docker_image_menu
                ;;
            6)
                echo ""
                docker_network_menu
                ;;
            7)
                echo ""
                docker_volume_menu
                ;;
            8)
                echo ""
                docker_compose_menu
                ;;
            0)
                return
                ;;
            *)
                print_error "无效的选择，请输入0-8之间的数字"
                ;;
        esac
        
        wait_for_key $choice
    done
}

# Docker安装
install_docker() {
    print_header "安装Docker"
    
    # 检查Docker是否已安装
    if command_exists docker; then
        print_warning "Docker已经安装"
        docker --version
        return 0
    fi
    
    case $PACKAGE_MANAGER in
        apt)
            install_docker_debian
            ;;
        yum|dnf)
            install_docker_rhel
            ;;
        pacman)
            install_docker_arch
            ;;
        zypper)
            install_docker_opensuse
            ;;
        apk)
            install_docker_alpine
            ;;
        *)
            print_error "不支持的包管理器: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    # 启动和启用Docker服务
    print_info "启动Docker服务..."
    service_start docker
    service_enable docker
    
    # 将用户添加到docker组
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        print_success "用户 $SUDO_USER 已添加到docker组"
        print_warning "请注销并重新登录以使组权限生效"
    fi
    
    print_success "Docker安装完成"
    docker --version
}

# Debian/Ubuntu Docker安装
install_docker_debian() {
    print_info "卸载旧版本Docker..."
    package_remove docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    print_info "安装依赖包..."
    package_install apt-transport-https ca-certificates gnupg lsb-release
    
    print_info "添加Docker官方GPG密钥..."
    curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    print_info "添加Docker APT仓库..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    package_update
    package_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# RHEL/CentOS/Fedora Docker安装
install_docker_rhel() {
    print_info "安装Docker..."
    package_install yum-utils
    
    case $DISTRO in
        centos|rhel|rocky|almalinux)
            $PACKAGE_MANAGER config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            ;;
        fedora)
            $PACKAGE_MANAGER config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            ;;
    esac
    
    package_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# Arch Linux Docker安装
install_docker_arch() {
    package_install docker docker-compose
}

# openSUSE Docker安装
install_docker_opensuse() {
    package_install docker docker-compose
}

# Alpine Linux Docker安装
install_docker_alpine() {
    package_install docker docker-compose
}

# 卸载Docker
uninstall_docker() {
    print_header "卸载Docker"
    
    if ! command_exists docker; then
        print_info "Docker未安装，无需卸载"
        return 0
    fi
    
    if ! confirm_action "确定要卸载Docker吗？这将删除所有容器和镜像"; then
        print_info "取消卸载"
        return 0
    fi
    
    print_info "停止Docker服务..."
    service_stop docker 2>/dev/null || true
    
    print_info "卸载Docker软件包..."
    case $PACKAGE_MANAGER in
        apt)
            package_remove docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        yum|dnf)
            package_remove docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        pacman)
            package_remove docker docker-compose
            ;;
        zypper)
            package_remove docker docker-compose
            ;;
        apk)
            package_remove docker docker-compose
            ;;
    esac
    
    print_info "删除Docker数据目录..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    
    print_success "Docker卸载完成"
}

# 显示Docker状态
show_docker_status() {
    print_header "Docker状态信息"
    
    if command_exists docker; then
        echo -e "${CYAN}◆ Docker版本${NC}"
        docker --version
        echo
        
        echo -e "${CYAN}◆ Docker服务状态${NC}"
        service_status docker
        echo
        
        echo -e "${CYAN}◆ 运行中的容器${NC}"
        docker ps 2>/dev/null || print_warning "无法获取容器信息，可能需要启动Docker服务"
        echo
        
        echo -e "${CYAN}◆ 所有容器${NC}"
        docker ps -a 2>/dev/null || true
        echo
        
        echo -e "${CYAN}◆ Docker镜像${NC}"
        docker images 2>/dev/null || true
        echo
        
        echo -e "${CYAN}◆ Docker磁盘使用${NC}"
        docker system df 2>/dev/null || true
    else
        print_error "Docker未安装"
    fi
}

# Docker容器管理
docker_container_menu() {
    if ! check_docker_availability; then
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker容器管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有容器"
        print_menu_item "2" "运行新容器"
        print_menu_item "3" "启动容器"
        print_menu_item "4" "停止容器"
        print_menu_item "5" "重启容器"
        print_menu_item "6" "删除容器"
        print_menu_item "7" "进入容器"
        print_menu_item "8" "查看容器日志"
        print_menu_item "9" "查看容器详情"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-9]: "
        read -r choice
        
        case $choice in
            1) docker ps -a ;;
            2) run_new_container ;;
            3) start_container ;;
            4) stop_container ;;
            5) restart_container ;;
            6) remove_container ;;
            7) enter_container ;;
            8) show_container_logs ;;
            9) show_container_details ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 检查Docker可用性
check_docker_availability() {
    if ! command_exists docker; then
        print_error "Docker未安装"
        return 1
    fi
    
    if ! service_is_active docker; then
        print_warning "Docker服务未运行，正在启动..."
        service_start docker
        sleep 3
        if ! service_is_active docker; then
            print_error "Docker服务启动失败"
            return 1
        fi
    fi
    
    return 0
}

# 运行新容器
run_new_container() {
    print_prompt "请输入镜像名 (如 nginx:latest): "
    read -r image_name
    
    if [[ -z "$image_name" ]]; then
        print_error "镜像名不能为空"
        return 1
    fi
    
    print_prompt "请输入容器名 (可选): "
    read -r container_name
    
    print_prompt "请输入端口映射 (如 80:80，可选): "
    read -r port_mapping
    
    # 构建docker run命令
    local cmd="docker run -d"
    
    if [[ -n "$container_name" ]]; then
        cmd="$cmd --name $container_name"
    fi
    
    if [[ -n "$port_mapping" ]]; then
        cmd="$cmd -p $port_mapping"
    fi
    
    cmd="$cmd $image_name"
    
    print_info "执行命令: $cmd"
    if eval "$cmd"; then
        print_success "容器启动成功"
    else
        print_error "容器启动失败"
    fi
}

# 启动容器
start_container() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    if docker start "$container"; then
        print_success "容器 $container 已启动"
    else
        print_error "容器 $container 启动失败"
    fi
}

# 停止容器
stop_container() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    if docker stop "$container"; then
        print_success "容器 $container 已停止"
    else
        print_error "容器 $container 停止失败"
    fi
}

# 重启容器
restart_container() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    if docker restart "$container"; then
        print_success "容器 $container 已重启"
    else
        print_error "容器 $container 重启失败"
    fi
}

# 删除容器
remove_container() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    if confirm_action "确定要删除容器 $container 吗？"; then
        if docker rm "$container"; then
            print_success "容器 $container 已删除"
        else
            print_error "容器 $container 删除失败"
        fi
    fi
}

# 进入容器
enter_container() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    docker exec -it "$container" /bin/bash 2>/dev/null || docker exec -it "$container" /bin/sh
}

# 显示容器日志
show_container_logs() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    print_prompt "显示行数 [50]: "
    read -r lines
    lines=${lines:-50}
    
    docker logs --tail "$lines" "$container"
}

# 显示容器详情
show_container_details() {
    print_prompt "请输入容器名或ID: "
    read -r container
    
    if [[ -z "$container" ]]; then
        print_error "容器名不能为空"
        return 1
    fi
    
    docker inspect "$container"
}

# Docker镜像管理
docker_image_menu() {
    if ! check_docker_availability; then
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker镜像管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有镜像"
        print_menu_item "2" "拉取镜像"
        print_menu_item "3" "删除镜像"
        print_menu_item "4" "清理无用镜像"
        print_menu_item "5" "导出镜像"
        print_menu_item "6" "导入镜像"
        print_menu_item "7" "搜索镜像"
        print_menu_item "8" "构建镜像"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-8]: "
        read -r choice
        
        case $choice in
            1) docker images ;;
            2) pull_image ;;
            3) remove_image ;;
            4) prune_images ;;
            5) export_image ;;
            6) import_image ;;
            7) search_image ;;
            8) build_image ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 拉取镜像
pull_image() {
    print_prompt "请输入镜像名 (如 nginx:latest): "
    read -r image
    
    if [[ -z "$image" ]]; then
        print_error "镜像名不能为空"
        return 1
    fi
    
    if docker pull "$image"; then
        print_success "镜像 $image 拉取成功"
    else
        print_error "镜像 $image 拉取失败"
    fi
}

# 删除镜像
remove_image() {
    print_prompt "请输入镜像名或ID: "
    read -r image
    
    if [[ -z "$image" ]]; then
        print_error "镜像名不能为空"
        return 1
    fi
    
    if confirm_action "确定要删除镜像 $image 吗？"; then
        if docker rmi "$image"; then
            print_success "镜像 $image 已删除"
        else
            print_error "镜像 $image 删除失败"
        fi
    fi
}

# 清理无用镜像
prune_images() {
    if confirm_action "确定要清理所有无用镜像吗？"; then
        print_info "清理无用镜像..."
        docker image prune -f
        print_success "无用镜像清理完成"
    fi
}

# 导出镜像
export_image() {
    print_prompt "请输入镜像名: "
    read -r image
    print_prompt "请输入导出文件名: "
    read -r filename
    
    if [[ -z "$image" || -z "$filename" ]]; then
        print_error "镜像名和文件名不能为空"
        return 1
    fi
    
    if docker save -o "$filename" "$image"; then
        print_success "镜像 $image 已导出到 $filename"
    else
        print_error "镜像导出失败"
    fi
}

# 导入镜像
import_image() {
    print_prompt "请输入镜像文件路径: "
    read -r filepath
    
    if [[ -z "$filepath" ]]; then
        print_error "文件路径不能为空"
        return 1
    fi
    
    if [[ ! -f "$filepath" ]]; then
        print_error "文件不存在: $filepath"
        return 1
    fi
    
    if docker load -i "$filepath"; then
        print_success "镜像导入成功"
    else
        print_error "镜像导入失败"
    fi
}

# 搜索镜像
search_image() {
    print_prompt "请输入搜索关键词: "
    read -r keyword
    
    if [[ -z "$keyword" ]]; then
        print_error "关键词不能为空"
        return 1
    fi
    
    docker search "$keyword"
}

# 构建镜像
build_image() {
    print_prompt "请输入Dockerfile路径 [当前目录]: "
    read -r dockerfile_path
    dockerfile_path=${dockerfile_path:-.}
    
    print_prompt "请输入镜像名和标签 (如 myapp:latest): "
    read -r image_tag
    
    if [[ -z "$image_tag" ]]; then
        print_error "镜像名不能为空"
        return 1
    fi
    
    if docker build -t "$image_tag" "$dockerfile_path"; then
        print_success "镜像 $image_tag 构建成功"
    else
        print_error "镜像构建失败"
    fi
}

# Docker网络管理
docker_network_menu() {
    if ! check_docker_availability; then
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker网络管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有网络"
        print_menu_item "2" "创建网络"
        print_menu_item "3" "删除网络"
        print_menu_item "4" "查看网络详情"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-4]: "
        read -r choice
        
        case $choice in
            1) docker network ls ;;
            2) create_network ;;
            3) remove_network ;;
            4) inspect_network ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 创建网络
create_network() {
    print_prompt "请输入网络名: "
    read -r network_name
    
    if [[ -z "$network_name" ]]; then
        print_error "网络名不能为空"
        return 1
    fi
    
    if docker network create "$network_name"; then
        print_success "网络 $network_name 创建成功"
    else
        print_error "网络创建失败"
    fi
}

# 删除网络
remove_network() {
    print_prompt "请输入网络名: "
    read -r network_name
    
    if [[ -z "$network_name" ]]; then
        print_error "网络名不能为空"
        return 1
    fi
    
    if confirm_action "确定要删除网络 $network_name 吗？"; then
        if docker network rm "$network_name"; then
            print_success "网络 $network_name 已删除"
        else
            print_error "网络删除失败"
        fi
    fi
}

# 查看网络详情
inspect_network() {
    print_prompt "请输入网络名: "
    read -r network_name
    
    if [[ -z "$network_name" ]]; then
        print_error "网络名不能为空"
        return 1
    fi
    
    docker network inspect "$network_name"
}

# Docker存储管理
docker_volume_menu() {
    if ! check_docker_availability; then
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker存储管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "查看所有存储卷"
        print_menu_item "2" "创建存储卷"
        print_menu_item "3" "删除存储卷"
        print_menu_item "4" "查看存储卷详情"
        print_menu_item "5" "清理无用存储卷"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-5]: "
        read -r choice
        
        case $choice in
            1) docker volume ls ;;
            2) create_volume ;;
            3) remove_volume ;;
            4) inspect_volume ;;
            5) prune_volumes ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 创建存储卷
create_volume() {
    print_prompt "请输入存储卷名: "
    read -r volume_name
    
    if [[ -z "$volume_name" ]]; then
        print_error "存储卷名不能为空"
        return 1
    fi
    
    if docker volume create "$volume_name"; then
        print_success "存储卷 $volume_name 创建成功"
    else
        print_error "存储卷创建失败"
    fi
}

# 删除存储卷
remove_volume() {
    print_prompt "请输入存储卷名: "
    read -r volume_name
    
    if [[ -z "$volume_name" ]]; then
        print_error "存储卷名不能为空"
        return 1
    fi
    
    if confirm_action "确定要删除存储卷 $volume_name 吗？"; then
        if docker volume rm "$volume_name"; then
            print_success "存储卷 $volume_name 已删除"
        else
            print_error "存储卷删除失败"
        fi
    fi
}

# 查看存储卷详情
inspect_volume() {
    print_prompt "请输入存储卷名: "
    read -r volume_name
    
    if [[ -z "$volume_name" ]]; then
        print_error "存储卷名不能为空"
        return 1
    fi
    
    docker volume inspect "$volume_name"
}

# 清理无用存储卷
prune_volumes() {
    if confirm_action "确定要清理所有无用存储卷吗？"; then
        print_info "清理无用存储卷..."
        docker volume prune -f
        print_success "无用存储卷清理完成"
    fi
}

# Docker Compose管理
docker_compose_menu() {
    if ! check_docker_availability; then
        return 1
    fi
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose未安装"
        print_info "请先安装Docker Compose"
        return 1
    fi
    
    while true; do
        clear
        print_header "Docker Compose管理"
        
        echo -e "${BOLD}请选择操作:${NC}"
        print_menu_item "1" "启动服务"
        print_menu_item "2" "停止服务"
        print_menu_item "3" "重启服务"
        print_menu_item "4" "查看服务状态"
        print_menu_item "5" "查看服务日志"
        print_menu_item "6" "拉取镜像"
        print_menu_item "7" "构建镜像"
        print_menu_item "8" "删除服务"
        print_menu_item "0" "返回"
        
        print_prompt "请选择操作 [0-8]: "
        read -r choice
        
        case $choice in
            1) compose_up ;;
            2) compose_down ;;
            3) compose_restart ;;
            4) compose_ps ;;
            5) compose_logs ;;
            6) compose_pull ;;
            7) compose_build ;;
            8) compose_down_remove ;;
            0) return ;;
            *) print_error "无效选择" ;;
        esac
        
        wait_for_key $choice
    done
}

# 获取docker-compose命令
get_compose_cmd() {
    if command_exists docker-compose; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# 启动Compose服务
compose_up() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    local compose_cmd=$(get_compose_cmd)
    
    if [[ ! -f "$compose_path/docker-compose.yml" ]] && [[ ! -f "$compose_path/compose.yml" ]]; then
        print_error "在 $compose_path 中未找到 docker-compose.yml 或 compose.yml 文件"
        return 1
    fi
    
    cd "$compose_path"
    if $compose_cmd up -d; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
    fi
}

# 停止Compose服务
compose_down() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    if $compose_cmd down; then
        print_success "服务停止成功"
    else
        print_error "服务停止失败"
    fi
}

# 重启Compose服务
compose_restart() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    if $compose_cmd restart; then
        print_success "服务重启成功"
    else
        print_error "服务重启失败"
    fi
}

# 查看Compose服务状态
compose_ps() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    $compose_cmd ps
}

# 查看Compose服务日志
compose_logs() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    print_prompt "请输入服务名 (留空查看所有服务): "
    read -r service_name
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    if [[ -n "$service_name" ]]; then
        $compose_cmd logs "$service_name"
    else
        $compose_cmd logs
    fi
}

# 拉取Compose镜像
compose_pull() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    if $compose_cmd pull; then
        print_success "镜像拉取成功"
    else
        print_error "镜像拉取失败"
    fi
}

# 构建Compose镜像
compose_build() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    if $compose_cmd build; then
        print_success "镜像构建成功"
    else
        print_error "镜像构建失败"
    fi
}

# 删除Compose服务
compose_down_remove() {
    print_prompt "请输入docker-compose.yml文件路径 [当前目录]: "
    read -r compose_path
    compose_path=${compose_path:-.}
    
    if ! confirm_action "确定要删除所有服务及其数据吗？"; then
        return 0
    fi
    
    local compose_cmd=$(get_compose_cmd)
    
    cd "$compose_path"
    if $compose_cmd down -v --remove-orphans; then
        print_success "服务删除成功"
    else
        print_error "服务删除失败"
    fi
}
