#!/bin/bash

set -e

echo "🚀 智能行为检测系统 - Docker部署脚本"
echo "========================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker环境
check_docker() {
    echo -e "${YELLOW}📋 检查Docker环境...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker未安装，请先安装Docker${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose未安装，请先安装Docker Compose${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker环境检查通过${NC}"
}

# 检查项目文件
check_files() {
    echo -e "${YELLOW}📁 检查项目文件...${NC}"
    
    required_files=(
        "backend/app.py"
        "backend/requirements.txt"
        "frontend/package.json"
        "yolo_slowfast-master/yolov8n.pt"
        "yolo_slowfast-master/SLOWFAST_8x8_R50_DETECTION.pyth"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ 缺少必要文件: $file${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✅ 项目文件检查通过${NC}"
}

# 创建必要目录
create_directories() {
    echo -e "${YELLOW}📂 创建必要目录...${NC}"
    
    directories=("uploads" "outputs" "logs" "database")
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        echo "创建目录: $dir"
    done
    
    echo -e "${GREEN}✅ 目录创建完成${NC}"
}

# 构建和启动服务
deploy_services() {
    echo -e "${YELLOW}🔨 构建Docker镜像...${NC}"
    docker-compose build --no-cache
    
    echo -e "${YELLOW}🚀 启动服务...${NC}"
    docker-compose up -d
    
    echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
    sleep 30
    
    # 检查服务状态
    echo -e "${YELLOW}📊 检查服务状态...${NC}"
    docker-compose ps
}

# 健康检查
health_check() {
    echo -e "${YELLOW}🏥 执行健康检查...${NC}"
    
    # 检查后端API
    if curl -f http://localhost:5001/api/health &> /dev/null; then
        echo -e "${GREEN}✅ 后端API健康${NC}"
    else
        echo -e "${RED}❌ 后端API异常${NC}"
        return 1
    fi
    
    # 检查前端
    if curl -f http://localhost &> /dev/null; then
        echo -e "${GREEN}✅ 前端服务健康${NC}"
    else
        echo -e "${RED}❌ 前端服务异常${NC}"
        return 1
    fi
    
    return 0
}

# 显示部署信息
show_info() {
    echo ""
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo "========================================"
    echo -e "前端地址: ${GREEN}http://localhost${NC}"
    echo -e "后端API: ${GREEN}http://localhost:5001${NC}"
    echo -e "健康检查: ${GREEN}http://localhost:5001/api/health${NC}"
    echo ""
    echo "常用命令:"
    echo "  查看日志: docker-compose logs -f"
    echo "  停止服务: docker-compose down"
    echo "  重启服务: docker-compose restart"
    echo "  查看状态: docker-compose ps"
    echo ""
}

# 主函数
main() {
    check_docker
    check_files
    create_directories
    deploy_services
    
    if health_check; then
        show_info
    else
        echo -e "${RED}❌ 部署失败，请检查日志${NC}"
        docker-compose logs
        exit 1
    fi
}

# 执行主函数
main "$@"
