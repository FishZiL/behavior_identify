#!/bin/bash

set -e

echo "🚀 智能行为检测系统 - Docker部署脚本"
echo "========================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
USE_GPU=false
USE_NGINX=false
COMPOSE_PROFILES="default"

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -g, --gpu         启用GPU加速"
    echo "  -n, --nginx       启用Nginx反向代理"
    echo "  -h, --help        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                # 基本部署"
    echo "  $0 --gpu          # 启用GPU加速"
    echo "  $0 --nginx        # 启用Nginx"
    echo "  $0 --gpu --nginx  # 启用GPU和Nginx"
    echo ""
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--gpu)
                USE_GPU=true
                shift
                ;;
            -n|--nginx)
                USE_NGINX=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # 根据参数设置配置
    if [ "$USE_GPU" = true ] && [ "$USE_NGINX" = true ]; then
        COMPOSE_PROFILES="gpu-nginx"
    elif [ "$USE_GPU" = true ]; then
        COMPOSE_PROFILES="gpu"
    elif [ "$USE_NGINX" = true ]; then
        COMPOSE_PROFILES="nginx"
    fi

    echo -e "${BLUE}📋 部署配置:${NC}"
    echo "  GPU加速: $USE_GPU"
    echo "  Nginx代理: $USE_NGINX"
    echo "  配置档案: $COMPOSE_PROFILES"
    echo ""
}

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

# 检查GPU环境
check_gpu() {
    if [ "$USE_GPU" = true ]; then
        echo -e "${YELLOW}🔍 检查GPU环境...${NC}"

        if ! command -v nvidia-smi &> /dev/null; then
            echo -e "${RED}❌ NVIDIA驱动未安装${NC}"
            echo "请先安装NVIDIA驱动"
            exit 1
        fi

        if ! docker info | grep -i nvidia &> /dev/null; then
            echo -e "${RED}❌ Docker不支持NVIDIA GPU${NC}"
            echo "请安装nvidia-docker2:"
            echo "sudo yum install -y nvidia-docker2"
            echo "sudo systemctl restart docker"
            exit 1
        fi

        echo -e "${GREEN}✅ GPU环境检查通过${NC}"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    fi
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

    # 构建镜像
    docker-compose --profile $COMPOSE_PROFILES build --no-cache

    echo -e "${YELLOW}🚀 启动服务...${NC}"

    # 启动服务
    if [ "$USE_GPU" = true ]; then
        echo -e "${BLUE}🎮 启用GPU加速...${NC}"
        # 设置GPU环境变量并启动
        NVIDIA_VISIBLE_DEVICES=all CUDA_VISIBLE_DEVICES=0 \
        docker-compose --profile $COMPOSE_PROFILES up -d
    else
        docker-compose --profile $COMPOSE_PROFILES up -d
    fi

    echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
    sleep 30

    # 检查服务状态
    echo -e "${YELLOW}📊 检查服务状态...${NC}"
    docker-compose --profile $COMPOSE_PROFILES ps
}

# 健康检查
health_check() {
    echo -e "${YELLOW}🏥 执行健康检查...${NC}"

    # 检查后端API
    echo "检查后端API..."
    for i in {1..10}; do
        if curl -f http://localhost:5001/api/health &> /dev/null; then
            echo -e "${GREEN}✅ 后端API健康${NC}"
            break
        else
            echo "等待后端启动... ($i/10)"
            sleep 5
        fi
        if [ $i -eq 10 ]; then
            echo -e "${RED}❌ 后端API异常${NC}"
            return 1
        fi
    done

    # 检查前端
    echo "检查前端服务..."
    frontend_port=80
    if [ "$USE_NGINX" = true ]; then
        frontend_port=8080
    fi

    for i in {1..5}; do
        if curl -f http://localhost:$frontend_port &> /dev/null; then
            echo -e "${GREEN}✅ 前端服务健康${NC}"
            break
        else
            echo "等待前端启动... ($i/5)"
            sleep 3
        fi
        if [ $i -eq 5 ]; then
            echo -e "${RED}❌ 前端服务异常${NC}"
            return 1
        fi
    done

    # 检查Nginx（如果启用）
    if [ "$USE_NGINX" = true ]; then
        echo "检查Nginx代理..."
        if curl -f http://localhost:8080/health &> /dev/null; then
            echo -e "${GREEN}✅ Nginx代理健康${NC}"
        else
            echo -e "${YELLOW}⚠️  Nginx代理可能未完全就绪${NC}"
        fi
    fi

    return 0
}

# 显示部署信息
show_info() {
    echo ""
    echo -e "${GREEN}🎉 部署完成！${NC}"
    echo "========================================"

    # 获取虚拟机IP
    VM_IP=$(hostname -I | awk '{print $1}')

    if [ "$USE_NGINX" = true ]; then
        echo -e "🌐 主要访问地址:"
        echo -e "  Nginx代理: ${GREEN}http://localhost:8080${NC}"
        echo -e "  Nginx代理: ${GREEN}http://$VM_IP:8080${NC}"
        echo ""
        echo -e "🔧 直接访问地址:"
        echo -e "  前端服务: ${BLUE}http://localhost:80${NC}"
        echo -e "  前端服务: ${BLUE}http://$VM_IP:80${NC}"
    else
        echo -e "🌐 访问地址:"
        echo -e "  前端服务: ${GREEN}http://localhost:80${NC}"
        echo -e "  前端服务: ${GREEN}http://$VM_IP:80${NC}"
    fi

    echo -e "  后端API: ${GREEN}http://localhost:5001${NC}"
    echo -e "  后端API: ${GREEN}http://$VM_IP:5001${NC}"
    echo -e "  健康检查: ${GREEN}http://localhost:5001/api/health${NC}"
    echo ""

    if [ "$USE_GPU" = true ]; then
        echo -e "${BLUE}🎮 GPU加速已启用${NC}"
        echo "  GPU信息:"
        nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | head -1
        echo ""
    fi

    echo -e "${YELLOW}📋 常用命令:${NC}"
    if [ "$USE_GPU" = true ]; then
        echo "  查看日志: docker-compose -f $COMPOSE_FILE logs -f"
        echo "  停止服务: docker-compose -f $COMPOSE_FILE down"
        echo "  重启服务: docker-compose -f $COMPOSE_FILE restart"
        echo "  查看状态: docker-compose -f $COMPOSE_FILE ps"
    else
        echo "  查看日志: docker-compose --profile $COMPOSE_PROFILES logs -f"
        echo "  停止服务: docker-compose --profile $COMPOSE_PROFILES down"
        echo "  重启服务: docker-compose --profile $COMPOSE_PROFILES restart"
        echo "  查看状态: docker-compose --profile $COMPOSE_PROFILES ps"
    fi
    echo ""

    echo -e "${BLUE}💡 提示:${NC}"
    echo "  - 在Windows浏览器中使用虚拟机IP地址访问"
    echo "  - 如果无法访问，请检查防火墙设置"
    echo "  - 使用 ./manage.sh 脚本进行服务管理"
    echo ""
}

# 主函数
main() {
    parse_args "$@"
    check_docker
    check_gpu
    check_files
    create_directories
    deploy_services

    if health_check; then
        show_info
    else
        echo -e "${RED}❌ 部署失败，请检查日志${NC}"
        if [ "$USE_GPU" = true ]; then
            docker-compose -f $COMPOSE_FILE logs
        else
            docker-compose --profile $COMPOSE_PROFILES logs
        fi
        exit 1
    fi
}

# 执行主函数
main "$@"
