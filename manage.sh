#!/bin/bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测当前部署配置
detect_config() {
    USE_GPU=false
    USE_NGINX=false
    COMPOSE_PROFILES="default"

    # 检查是否有GPU容器运行
    if docker ps --format "table {{.Names}}" | grep -q "behavior-backend" && \
       docker inspect behavior-backend 2>/dev/null | grep -q "nvidia"; then
        USE_GPU=true
        COMPOSE_PROFILES="gpu"
    fi

    # 检查是否有Nginx容器运行
    if docker ps --format "table {{.Names}}" | grep -q "behavior-nginx"; then
        USE_NGINX=true
        if [ "$USE_GPU" = true ]; then
            COMPOSE_PROFILES="gpu-nginx"
        else
            COMPOSE_PROFILES="nginx"
        fi
    fi
}

# 显示帮助信息
show_help() {
    detect_config
    echo "智能行为检测系统 - 管理脚本"
    echo "用法: ./manage.sh [命令]"
    echo ""
    echo -e "${BLUE}当前配置:${NC}"
    echo "  GPU加速: $USE_GPU"
    echo "  Nginx代理: $USE_NGINX"
    echo "  配置档案: $COMPOSE_PROFILES"
    echo ""
    echo "可用命令:"
    echo "  start     - 启动所有服务"
    echo "  stop      - 停止所有服务"
    echo "  restart   - 重启所有服务"
    echo "  status    - 查看服务状态"
    echo "  logs      - 查看服务日志"
    echo "  clean     - 清理Docker资源"
    echo "  backup    - 备份数据"
    echo "  restore   - 恢复数据"
    echo "  update    - 更新服务"
    echo "  health    - 健康检查"
    echo "  gpu       - 显示GPU信息"
    echo ""
}

# 启动服务
start_services() {
    detect_config
    echo -e "${YELLOW}🚀 启动服务...${NC}"

    docker-compose --profile $COMPOSE_PROFILES up -d

    echo -e "${GREEN}✅ 服务启动完成${NC}"
}

# 停止服务
stop_services() {
    detect_config
    echo -e "${YELLOW}⏹️  停止服务...${NC}"

    docker-compose --profile $COMPOSE_PROFILES down

    echo -e "${GREEN}✅ 服务停止完成${NC}"
}

# 重启服务
restart_services() {
    detect_config
    echo -e "${YELLOW}🔄 重启服务...${NC}"

    docker-compose --profile $COMPOSE_PROFILES restart

    echo -e "${GREEN}✅ 服务重启完成${NC}"
}

# 查看状态
show_status() {
    echo -e "${BLUE}📊 服务状态:${NC}"
    docker-compose ps
    echo ""
    echo -e "${BLUE}💾 磁盘使用:${NC}"
    docker system df
}

# 查看日志
show_logs() {
    echo -e "${BLUE}📋 服务日志:${NC}"
    docker-compose logs -f --tail=100
}

# 清理资源
clean_resources() {
    echo -e "${YELLOW}🧹 清理Docker资源...${NC}"
    
    # 停止服务
    docker-compose down
    
    # 清理未使用的镜像
    docker image prune -f
    
    # 清理未使用的容器
    docker container prune -f
    
    # 清理未使用的网络
    docker network prune -f
    
    echo -e "${GREEN}✅ 清理完成${NC}"
}

# 备份数据
backup_data() {
    echo -e "${YELLOW}💾 备份数据...${NC}"
    
    backup_dir="backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份数据库
    if [ -d "database" ]; then
        cp -r database "$backup_dir/"
        echo "数据库备份完成"
    fi
    
    # 备份上传文件
    if [ -d "uploads" ]; then
        cp -r uploads "$backup_dir/"
        echo "上传文件备份完成"
    fi
    
    # 备份输出文件
    if [ -d "outputs" ]; then
        cp -r outputs "$backup_dir/"
        echo "输出文件备份完成"
    fi
    
    echo -e "${GREEN}✅ 备份完成: $backup_dir${NC}"
}

# 恢复数据
restore_data() {
    echo -e "${YELLOW}🔄 恢复数据...${NC}"
    
    if [ -z "$2" ]; then
        echo -e "${RED}❌ 请指定备份目录${NC}"
        echo "用法: ./manage.sh restore <备份目录>"
        exit 1
    fi
    
    backup_dir="$2"
    
    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}❌ 备份目录不存在: $backup_dir${NC}"
        exit 1
    fi
    
    # 停止服务
    docker-compose down
    
    # 恢复数据
    if [ -d "$backup_dir/database" ]; then
        rm -rf database
        cp -r "$backup_dir/database" ./
        echo "数据库恢复完成"
    fi
    
    if [ -d "$backup_dir/uploads" ]; then
        rm -rf uploads
        cp -r "$backup_dir/uploads" ./
        echo "上传文件恢复完成"
    fi
    
    if [ -d "$backup_dir/outputs" ]; then
        rm -rf outputs
        cp -r "$backup_dir/outputs" ./
        echo "输出文件恢复完成"
    fi
    
    echo -e "${GREEN}✅ 恢复完成${NC}"
}

# 更新服务
update_services() {
    echo -e "${YELLOW}🔄 更新服务...${NC}"
    
    # 拉取最新代码
    git pull
    
    # 重新构建镜像
    docker-compose build --no-cache
    
    # 重启服务
    docker-compose up -d
    
    echo -e "${GREEN}✅ 更新完成${NC}"
}

# 健康检查
health_check() {
    echo -e "${BLUE}🏥 健康检查:${NC}"
    
    # 检查后端
    if curl -f http://localhost:5001/api/health &> /dev/null; then
        echo -e "${GREEN}✅ 后端服务正常${NC}"
    else
        echo -e "${RED}❌ 后端服务异常${NC}"
    fi
    
    # 检查前端
    if curl -f http://localhost &> /dev/null; then
        echo -e "${GREEN}✅ 前端服务正常${NC}"
    else
        echo -e "${RED}❌ 前端服务异常${NC}"
    fi
    
    # 检查容器状态
    echo ""
    echo -e "${BLUE}📊 容器状态:${NC}"
    docker-compose ps
}

# 主函数
main() {
    case "$1" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        clean)
            clean_resources
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data "$@"
            ;;
        update)
            update_services
            ;;
        health)
            health_check
            ;;
        gpu)
            show_gpu_info
            ;;
        *)
            show_help
            ;;
    esac
}

# 显示GPU信息
show_gpu_info() {
    echo -e "${BLUE}🎮 GPU信息${NC}"
    echo "=========================="

    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✅ NVIDIA驱动已安装${NC}"
        echo ""
        nvidia-smi
        echo ""

        # 检查Docker GPU支持
        if docker info | grep -i nvidia &> /dev/null; then
            echo -e "${GREEN}✅ Docker支持GPU${NC}"
        else
            echo -e "${RED}❌ Docker不支持GPU${NC}"
        fi

        # 检查GPU容器
        if docker ps --format "table {{.Names}}" | grep -q "behavior-backend" && \
           docker inspect behavior-backend 2>/dev/null | grep -q "nvidia"; then
            echo -e "${GREEN}✅ 当前部署使用GPU加速${NC}"
        else
            echo -e "${YELLOW}⚠️  当前部署未使用GPU加速${NC}"
        fi
    else
        echo -e "${RED}❌ NVIDIA驱动未安装${NC}"
    fi
}

# 执行主函数
main "$@"
