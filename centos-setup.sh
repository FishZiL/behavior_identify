#!/bin/bash

# CentOS Docker环境自动配置脚本
# 适用于Windows + CentOS虚拟机环境

set -e

echo "🐧 CentOS Docker环境配置脚本"
echo "================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否为root用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}❌ 请不要使用root用户运行此脚本${NC}"
        echo "请使用普通用户，脚本会在需要时使用sudo"
        exit 1
    fi
}

# 检查CentOS版本
check_centos() {
    echo -e "${YELLOW}📋 检查系统版本...${NC}"
    
    if [ ! -f /etc/centos-release ]; then
        echo -e "${RED}❌ 此脚本仅适用于CentOS系统${NC}"
        exit 1
    fi
    
    centos_version=$(cat /etc/centos-release)
    echo -e "${GREEN}✅ 系统版本: $centos_version${NC}"
}

# 更新系统
update_system() {
    echo -e "${YELLOW}🔄 更新系统包...${NC}"
    sudo yum update -y
    sudo yum install -y curl wget git vim net-tools
    echo -e "${GREEN}✅ 系统更新完成${NC}"
}

# 安装Docker
install_docker() {
    echo -e "${YELLOW}🐳 安装Docker...${NC}"
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker已安装${NC}"
        return
    fi
    
    # 安装Docker仓库
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # 安装Docker
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    
    # 启动Docker服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 将当前用户添加到docker组
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}✅ Docker安装完成${NC}"
    echo -e "${YELLOW}⚠️  请重新登录或执行 'newgrp docker' 以应用用户组更改${NC}"
}

# 安装Docker Compose
install_docker_compose() {
    echo -e "${YELLOW}🔧 安装Docker Compose...${NC}"
    
    # 检查Docker Compose是否已安装
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✅ Docker Compose已安装${NC}"
        return
    fi
    
    # 下载Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # 赋予执行权限
    sudo chmod +x /usr/local/bin/docker-compose
    
    # 创建软链接
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    echo -e "${GREEN}✅ Docker Compose安装完成${NC}"
}

# 配置防火墙
configure_firewall() {
    echo -e "${YELLOW}🔥 配置防火墙...${NC}"
    
    # 检查防火墙状态
    if ! systemctl is-active --quiet firewalld; then
        echo -e "${YELLOW}⚠️  防火墙未启动，启动防火墙...${NC}"
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
    fi
    
    # 开放必要端口
    sudo firewall-cmd --permanent --add-port=5001/tcp  # 后端API
    sudo firewall-cmd --permanent --add-port=80/tcp    # 前端
    sudo firewall-cmd --permanent --add-port=8080/tcp  # Nginx
    sudo firewall-cmd --permanent --add-port=22/tcp    # SSH
    
    # 重载防火墙配置
    sudo firewall-cmd --reload
    
    echo -e "${GREEN}✅ 防火墙配置完成${NC}"
    echo -e "${BLUE}📋 开放的端口:${NC}"
    sudo firewall-cmd --list-ports
}

# 配置Docker镜像加速
configure_docker_mirror() {
    echo -e "${YELLOW}🚀 配置Docker镜像加速...${NC}"
    
    # 创建Docker配置目录
    sudo mkdir -p /etc/docker
    
    # 配置镜像加速器
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    # 重启Docker服务
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    echo -e "${GREEN}✅ Docker镜像加速配置完成${NC}"
}

# 创建项目目录
create_project_dir() {
    echo -e "${YELLOW}📁 创建项目目录...${NC}"
    
    project_dir="$HOME/behavior_identify"
    
    if [ ! -d "$project_dir" ]; then
        mkdir -p "$project_dir"
        echo -e "${GREEN}✅ 项目目录创建: $project_dir${NC}"
    else
        echo -e "${GREEN}✅ 项目目录已存在: $project_dir${NC}"
    fi
    
    # 创建必要的子目录
    cd "$project_dir"
    mkdir -p uploads outputs logs database
    
    echo -e "${BLUE}📋 项目目录结构:${NC}"
    ls -la
}

# 显示网络信息
show_network_info() {
    echo -e "${BLUE}🌐 网络配置信息:${NC}"
    echo "================================"
    
    # 显示IP地址
    echo -e "${YELLOW}IP地址:${NC}"
    hostname -I
    
    # 显示网络接口
    echo -e "${YELLOW}网络接口:${NC}"
    ip addr show | grep -E "inet.*scope global"
    
    # 显示路由信息
    echo -e "${YELLOW}默认网关:${NC}"
    ip route | grep default
    
    echo "================================"
    echo -e "${GREEN}💡 在Windows中访问虚拟机服务:${NC}"
    echo "   后端API: http://$(hostname -I | awk '{print $1}'):5001"
    echo "   前端界面: http://$(hostname -I | awk '{print $1}'):80"
    echo ""
}

# 验证安装
verify_installation() {
    echo -e "${YELLOW}🔍 验证安装...${NC}"
    
    # 验证Docker
    if docker --version &> /dev/null; then
        echo -e "${GREEN}✅ Docker: $(docker --version)${NC}"
    else
        echo -e "${RED}❌ Docker安装失败${NC}"
        return 1
    fi
    
    # 验证Docker Compose
    if docker-compose --version &> /dev/null; then
        echo -e "${GREEN}✅ Docker Compose: $(docker-compose --version)${NC}"
    else
        echo -e "${RED}❌ Docker Compose安装失败${NC}"
        return 1
    fi
    
    # 验证Docker服务
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✅ Docker服务运行正常${NC}"
    else
        echo -e "${RED}❌ Docker服务未运行${NC}"
        return 1
    fi
    
    # 测试Docker权限
    if docker ps &> /dev/null; then
        echo -e "${GREEN}✅ Docker权限配置正确${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker权限需要重新登录生效${NC}"
    fi
    
    return 0
}

# 显示后续步骤
show_next_steps() {
    echo ""
    echo -e "${GREEN}🎉 CentOS Docker环境配置完成！${NC}"
    echo "================================"
    echo -e "${YELLOW}后续步骤:${NC}"
    echo ""
    echo "1. 重新登录或执行以下命令应用用户组更改:"
    echo "   newgrp docker"
    echo ""
    echo "2. 将项目文件传输到虚拟机:"
    echo "   - 使用WinSCP/FileZilla传输文件"
    echo "   - 或使用共享文件夹"
    echo "   - 或使用Git克隆项目"
    echo ""
    echo "3. 进入项目目录并部署:"
    echo "   cd ~/behavior_identify"
    echo "   chmod +x deploy.sh"
    echo "   ./deploy.sh"
    echo ""
    echo "4. 在Windows浏览器中访问:"
    echo "   http://$(hostname -I | awk '{print $1}'):5001"
    echo ""
    echo -e "${BLUE}💡 提示: 如果无法从Windows访问，请检查虚拟机网络配置${NC}"
    echo ""
}

# 主函数
main() {
    check_root
    check_centos
    update_system
    install_docker
    install_docker_compose
    configure_firewall
    configure_docker_mirror
    create_project_dir
    show_network_info
    
    if verify_installation; then
        show_next_steps
    else
        echo -e "${RED}❌ 安装验证失败，请检查错误信息${NC}"
        exit 1
    fi
}

# 执行主函数
main "$@"
