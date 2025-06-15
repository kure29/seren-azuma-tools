# Seren Azuma Linux Tools v3.0

通用Linux系统管理脚本集合 - 模块化版本

## 📋 功能特性

### 🔧 软件管理
- 系统更新与升级
- 常用工具安装
- 软件包搜索与管理
- 系统清理
- 进程、磁盘、内存管理
- 服务管理

### 🐳 Docker管理
- Docker安装/卸载
- 容器管理 (创建、启动、停止、删除)
- 镜像管理 (拉取、删除、导入导出)
- 网络管理
- 存储卷管理
- Docker Compose管理

### ⚙️ 系统管理
- 系统信息概览
- 用户管理
- DNS配置
- 时区设置
- 定时任务管理
- 密码修改

### 🔒 安全管理
- SSH管理与安全加固
- UFW防火墙配置
- Fail2ban入侵防护
- SSL证书管理
- 系统安全扫描
- 安全日志分析

### 🌐 网络管理
- 网络诊断工具
- 网络配置 (静态IP/DHCP)
- 带宽测试
- 端口扫描
- 网络监控
- DNS工具

### 🚀 节点搭建
- Snell代理节点
- 3X-UI管理面板
- V2Ray节点
- Trojan节点
- Shadowsocks节点
- WireGuard VPN
- OpenVPN服务器
- 节点配置备份恢复

## 📁 目录结构

```
linux_tools/
├── main.sh           # 主入口脚本
├── lib/              # 公共库
│   ├── config.sh     # 配置文件
│   ├── common.sh     # 公共函数
│   └── ui.sh         # 界面函数
└── modules/          # 功能模块
    ├── system.sh     # 系统管理
    ├── software.sh   # 软件管理
    ├── docker.sh     # Docker管理
    ├── security.sh   # 安全管理
    ├── network.sh    # 网络管理
    └── nodes.sh      # 节点部署
```

## 🚀 快速开始

### 1. 下载脚本

```bash
# 方法1: 直接下载
wget -O linux_tools.tar.gz https://github.com/your-repo/linux_tools/archive/main.tar.gz
tar -xzf linux_tools.tar.gz
cd linux_tools

# 方法2: Git克隆
git clone https://github.com/your-repo/linux_tools.git
cd linux_tools
```

### 2. 设置权限

```bash
chmod +x main.sh
chmod +x lib/*.sh
chmod +x modules/*.sh
```

### 3. 运行脚本

```bash
sudo ./main.sh
```

## 💻 支持的系统

- **Debian系**: Ubuntu, Debian, Linux Mint, Pop!_OS
- **RHEL系**: CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora
- **Arch系**: Arch Linux, Manjaro, Garuda, EndeavourOS
- **SUSE系**: openSUSE, SLES
- **Alpine**: Alpine Linux

## 🔧 系统要求

- **权限**: 需要root权限或sudo权限
- **网络**: 部分功能需要互联网连接
- **依赖**: 基本的Linux命令行工具

## 📝 使用示例

### 软件管理
```bash
# 系统更新
选择: 1 (软件管理) -> 1 (系统更新)

# 安装常用工具
选择: 1 (软件管理) -> 2 (安装常用工具)
```

### Docker管理
```bash
# 安装Docker
选择: 2 (Docker管理) -> 1 (安装Docker)

# 容器管理
选择: 2 (Docker管理) -> 4 (Docker容器管理)
```

### 安全管理
```bash
# SSH安全加固
选择: 4 (安全管理) -> 1 (SSH管理) -> 6 (SSH安全加固)

# 防火墙配置
选择: 4 (安全管理) -> 2 (UFW防火墙管理)
```

### 节点搭建
```bash
# 部署3X-UI面板
选择: 6 (节点搭建) -> 2 (3X-UI 面板)

# 部署V2Ray节点
选择: 6 (节点搭建) -> 3 (V2Ray 节点)
```

## 🔍 故障排除

### 常见问题

1. **权限不足**
   ```bash
   sudo ./main.sh
   ```

2. **网络连接失败**
   - 检查网络连接
   - 确认DNS设置
   - 尝试更换软件源

3. **包管理器错误**
   - 更新软件包列表
   - 检查系统版本兼容性

4. **服务启动失败**
   - 查看服务日志: `journalctl -u service_name`
   - 检查配置文件语法
   - 确认端口未被占用

### 日志查看

```bash
# 查看脚本日志
tail -f system_manager.log

# 查看系统日志
journalctl -f
```

## 🤝 贡献指南

1. Fork项目
2. 创建功能分支: `git checkout -b feature/new-feature`
3. 提交更改: `git commit -am 'Add new feature'`
4. 推送到分支: `git push origin feature/new-feature`
5. 提交Pull Request

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙋‍♂️ 支持

- **Issues**: [GitHub Issues](https://github.com/your-repo/linux_tools/issues)
- **讨论**: [GitHub Discussions](https://github.com/your-repo/linux_tools/discussions)
- **文档**: [项目Wiki](https://github.com/your-repo/linux_tools/wiki)

## 📚 更新日志

### v3.0 (模块化版本)
- ✨ 完全模块化重构
- 🎨 优化用户界面
- 🔧 新增Docker管理
- 🔒 强化安全功能
- 🌐 增强网络工具
- 🚀 扩展节点部署

### v2.3 (单文件版本)
- 🐛 修复系统兼容性问题
- ⚡ 优化执行性能
- 📱 改进用户体验

## ⭐ Star History

如果这个项目对您有帮助，请给我们一个Star ⭐

---

**作者**: 東雪蓮 (Seren Azuma)  
**版本**: 3.0  
**更新**: 2024年
