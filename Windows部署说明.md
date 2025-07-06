# 🖥️ Windows + CentOS虚拟机部署说明

## 📋 概述

本文档详细说明如何在Windows主机上通过CentOS虚拟机部署智能行为检测系统。

## 🛠️ 环境准备

### 1. Windows主机要求
- Windows 10/11 操作系统
- 至少8GB内存（推荐16GB）
- 至少100GB可用磁盘空间
- 支持虚拟化技术（Intel VT-x 或 AMD-V）

### 2. 虚拟化软件选择

#### VMware Workstation Pro（推荐）
- **优点**: 性能好，功能完整，网络配置灵活
- **缺点**: 商业软件，需要购买许可证
- **下载**: https://www.vmware.com/products/workstation-pro.html

#### VirtualBox（免费）
- **优点**: 免费开源，功能基本够用
- **缺点**: 性能相对较差
- **下载**: https://www.virtualbox.org/

### 3. CentOS镜像下载
- **CentOS 7**: https://mirrors.aliyun.com/centos/7/isos/x86_64/
- **CentOS 8**: https://mirrors.aliyun.com/centos/8/isos/x86_64/
- **推荐**: CentOS-7-x86_64-DVD-2009.iso

## 🚀 虚拟机创建和配置

### 1. VMware虚拟机配置

#### 创建虚拟机
1. 打开VMware Workstation
2. 选择"创建新的虚拟机"
3. 选择"典型"配置
4. 选择"稍后安装操作系统"
5. 选择"Linux" → "CentOS 7 64位"

#### 硬件配置
```
内存: 4GB（最小）/ 8GB（推荐）
处理器: 2核心（最小）/ 4核心（推荐）
硬盘: 50GB（最小）/ 100GB（推荐）
网络适配器: NAT模式（推荐）或桥接模式
```

#### 网络配置
**NAT模式（推荐）**:
1. 虚拟机设置 → 网络适配器 → NAT
2. 点击"NAT设置" → "端口转发"
3. 添加转发规则:
   - 主机端口5001 → 虚拟机端口5001 (后端API)
   - 主机端口8080 → 虚拟机端口80 (前端界面)

**桥接模式**:
1. 虚拟机设置 → 网络适配器 → 桥接模式
2. 选择物理网络适配器
3. 虚拟机将获得独立IP地址

### 2. CentOS系统安装

#### 安装步骤
1. 启动虚拟机，选择CentOS ISO镜像
2. 选择"Install CentOS 7"
3. 语言选择：中文（简体）或English
4. 安装摘要配置：
   - **软件选择**: 最小安装 + 开发工具
   - **安装位置**: 自动分区
   - **网络和主机名**: 启用网络连接
   - **用户设置**: 创建普通用户（不要只使用root）

#### 首次启动配置
```bash
# 更新系统
sudo yum update -y

# 安装必要工具
sudo yum install -y wget curl git vim net-tools

# 检查网络连接
ping baidu.com
```

## 📁 文件传输方案

### 方案一：WinSCP/FileZilla（推荐）

#### 使用WinSCP
1. 下载安装WinSCP: https://winscp.net/
2. 连接配置：
   - 文件协议: SFTP
   - 主机名: 虚拟机IP地址
   - 端口: 22
   - 用户名: CentOS用户名
   - 密码: CentOS用户密码
3. 连接后直接拖拽传输项目文件

#### 获取虚拟机IP地址
```bash
# 在CentOS中执行
ip addr show
# 或
ifconfig
```

### 方案二：VMware共享文件夹

#### 配置共享文件夹
1. 虚拟机 → 设置 → 选项 → 共享文件夹
2. 启用共享文件夹
3. 添加共享文件夹：
   - 主机路径: Windows项目目录
   - 名称: behavior_identify
   - 启用: 总是启用

#### 在CentOS中访问
```bash
# 安装VMware Tools（如果未安装）
sudo yum install -y open-vm-tools

# 挂载共享文件夹
sudo mkdir /mnt/shared
sudo mount -t fuse.vmhgfs-fuse .host:/ /mnt/shared -o allow_other

# 复制项目文件
cp -r /mnt/shared/behavior_identify ~/
```

### 方案三：Git仓库

#### 如果项目已上传到Git
```bash
# 在CentOS中克隆项目
git clone <your-repository-url>
cd behavior_identify
```

## 🐳 Docker环境配置

### 自动配置（推荐）
```bash
# 下载并运行配置脚本
wget https://raw.githubusercontent.com/your-repo/behavior_identify/main/centos-setup.sh
chmod +x centos-setup.sh
./centos-setup.sh
```

### 手动配置
```bash
# 更新系统
sudo yum update -y

# 安装Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到docker组
sudo usermod -aG docker $USER
newgrp docker

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 配置防火墙
sudo firewall-cmd --permanent --add-port=5001/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
```

## 🚀 项目部署

### 1. 准备项目文件
```bash
# 进入项目目录
cd ~/behavior_identify

# 检查文件完整性
ls -la
ls yolo_slowfast-master/*.pt
ls yolo_slowfast-master/*.pyth
```

### 2. 一键部署
```bash
# 赋予执行权限
chmod +x deploy.sh manage.sh

# 执行部署
./deploy.sh
```

### 3. 验证部署
```bash
# 检查容器状态
docker ps

# 检查服务健康
curl http://localhost:5001/api/health

# 查看日志
docker logs behavior-detection
```

## 🌐 Windows访问配置

### 获取访问地址
```bash
# 在CentOS中获取IP地址
hostname -I
```

### 访问地址
- **后端API**: http://虚拟机IP:5001
- **前端界面**: http://虚拟机IP:80 (多容器部署)
- **健康检查**: http://虚拟机IP:5001/api/health

### 浏览器测试
在Windows浏览器中访问：
- http://192.168.xxx.xxx:5001/api/health
- 应该返回JSON格式的健康状态

## 🔧 常见问题解决

### 1. 无法从Windows访问虚拟机服务
```bash
# 检查防火墙
sudo firewall-cmd --list-ports

# 检查服务监听
netstat -tlnp | grep :5001

# 临时关闭防火墙测试
sudo systemctl stop firewalld
```

### 2. 虚拟机网络问题
- 检查VMware网络配置
- 尝试重启网络服务: `sudo systemctl restart network`
- 检查IP地址分配: `ip addr show`

### 3. Docker权限问题
```bash
# 重新添加用户到docker组
sudo usermod -aG docker $USER
newgrp docker

# 或重新登录系统
```

### 4. 内存不足
- 增加虚拟机内存分配
- 关闭不必要的服务
- 使用CPU模式而非GPU模式

## 📋 部署检查清单

### 虚拟机准备
- [ ] VMware/VirtualBox已安装
- [ ] CentOS虚拟机已创建并配置
- [ ] 网络连接正常
- [ ] 防火墙端口已开放

### Docker环境
- [ ] Docker已安装并启动
- [ ] Docker Compose已安装
- [ ] 用户已添加到docker组
- [ ] Docker镜像加速已配置

### 项目文件
- [ ] 项目文件已传输到虚拟机
- [ ] AI模型文件完整
- [ ] 脚本文件有执行权限

### 服务部署
- [ ] 容器构建成功
- [ ] 服务启动正常
- [ ] 健康检查通过
- [ ] Windows可以访问服务

## 🎯 性能优化建议

### 虚拟机优化
- 分配足够的内存和CPU核心
- 启用虚拟化加速功能
- 使用SSD存储提升I/O性能

### Docker优化
- 配置镜像加速器
- 限制容器资源使用
- 定期清理无用镜像和容器

### 网络优化
- 使用桥接模式获得更好的网络性能
- 配置静态IP避免地址变化
- 优化防火墙规则

---

**部署完成后，您可以在Windows浏览器中访问智能行为检测系统！**
