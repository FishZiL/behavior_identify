# 🐳 智能行为检测系统 Docker 部署指南

## 📋 项目概述

本项目是一个基于YOLOv8+SlowFast算法的智能行为检测系统，采用前后端分离架构：

- **前端**: Vue.js 3 + Element Plus + ECharts
- **后端**: Flask + SQLAlchemy + SocketIO  
- **数据库**: SQLite
- **AI模型**: YOLOv8 + SlowFast + DeepSort
- **实时通信**: WebSocket

## 🏗️ 系统架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx代理     │    │   Vue.js前端    │    │   Flask后端     │
│   (可选)        │◄──►│   端口: 8080    │◄──►│   端口: 5001    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                               ┌─────────────────┐
                                               │   SQLite数据库  │
                                               │   + 文件存储    │
                                               └─────────────────┘
```

## 📁 项目结构分析

```
behavior_identify/
├── backend/                 # Flask后端服务
│   ├── app.py              # 主应用入口
│   ├── config/             # 配置文件
│   ├── models/             # 数据模型
│   ├── services/           # 业务逻辑
│   ├── utils/              # 工具函数
│   └── requirements.txt    # Python依赖
├── frontend/               # Vue.js前端
│   ├── src/                # 源代码
│   ├── public/             # 静态资源
│   ├── package.json        # Node.js依赖
│   └── vue.config.js       # Vue配置
├── yolo_slowfast-master/   # AI模型核心
│   ├── *.pt               # 预训练模型文件
│   ├── *.pyth             # SlowFast权重
│   └── requirements.txt    # 模型依赖
├── uploads/                # 上传文件目录
├── outputs/                # 输出文件目录
├── logs/                   # 日志文件
└── database/               # 数据库文件
```

## 🐳 Docker化方案

### 方案一：单容器部署（推荐用于开发/测试）

#### 1. 创建统一Dockerfile

```dockerfile
# 多阶段构建 - 前端构建阶段
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install --registry=https://registry.npmmirror.com
COPY frontend/ ./
RUN npm run build

# 主应用阶段 - Python环境
FROM python:3.9-slim

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglib2.0-0 \
    libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制并安装Python依赖
COPY backend/requirements.txt ./backend/
COPY yolo_slowfast-master/requirements.txt ./yolo_slowfast-master/
RUN pip install --no-cache-dir -r backend/requirements.txt \
    && pip install --no-cache-dir -r yolo_slowfast-master/requirements.txt

# 复制应用代码
COPY backend/ ./backend/
COPY yolo_slowfast-master/ ./yolo_slowfast-master/

# 复制前端构建结果
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# 创建必要目录
RUN mkdir -p uploads outputs logs database

# 设置环境变量
ENV PYTHONPATH=/app
ENV FLASK_APP=backend/app.py
ENV FLASK_ENV=production

# 暴露端口
EXPOSE 5001

# 启动命令
CMD ["python", "backend/app.py"]
```

### 方案二：多容器部署（推荐用于生产环境）

#### 1. 后端Dockerfile

```dockerfile
FROM python:3.9-slim

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc g++ libglib2.0-0 libsm6 libxext6 \
    libxrender-dev libgomp1 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 安装Python依赖
COPY requirements.txt yolo_slowfast-requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir -r yolo_slowfast-requirements.txt

# 复制应用代码
COPY backend/ ./backend/
COPY yolo_slowfast-master/ ./yolo_slowfast-master/

# 创建目录
RUN mkdir -p uploads outputs logs database

ENV PYTHONPATH=/app
EXPOSE 5001

CMD ["python", "backend/app.py"]
```

#### 2. 前端Dockerfile

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install --registry=https://registry.npmmirror.com
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

#### 3. Docker Compose配置

```yaml
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    container_name: behavior-backend
    ports:
      - "5001:5001"
    volumes:
      - ./uploads:/app/uploads
      - ./outputs:/app/outputs
      - ./logs:/app/logs
      - ./database:/app/database
      - ./yolo_slowfast-master:/app/yolo_slowfast-master
    environment:
      - FLASK_ENV=production
      - PYTHONPATH=/app
    restart: unless-stopped
    networks:
      - behavior-network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: behavior-frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - behavior-network

networks:
  behavior-network:
    driver: bridge

volumes:
  uploads:
  outputs:
  logs:
  database:
```

## ⚙️ 配置文件调整

### 1. 后端配置调整 (backend/config/config.py)

```python
import os

class Config:
    # 数据库配置 - Docker环境
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or \
        'sqlite:///database/behavior_detection.db'
    
    # 文件路径配置
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/outputs'
    
    # 模型路径配置
    MODEL_PATH = '/app/yolo_slowfast-master'
    YOLO_MODEL_PATH = os.path.join(MODEL_PATH, 'yolov8n.pt')
    SLOWFAST_WEIGHTS_PATH = os.path.join(MODEL_PATH, 'SLOWFAST_8x8_R50_DETECTION.pyth')
    
    # 服务配置
    HOST = '0.0.0.0'  # Docker容器内监听所有接口
    PORT = 5001
```

### 2. 前端Nginx配置 (frontend/nginx.conf)

```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # 前端路由
        location / {
            try_files $uri $uri/ /index.html;
        }

        # API代理
        location /api/ {
            proxy_pass http://backend:5001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # WebSocket代理
        location /socket.io/ {
            proxy_pass http://backend:5001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
        }

        # 视频流代理
        location /video_feed {
            proxy_pass http://backend:5001;
            proxy_set_header Host $host;
        }
    }
}
```

## 🖥️ Windows + CentOS虚拟机部署指南

### 环境准备

#### 1. Windows主机准备
- 安装VMware Workstation或VirtualBox
- 下载CentOS 7/8 ISO镜像
- 创建虚拟机（推荐配置：4GB内存，50GB硬盘）

#### 2. CentOS虚拟机配置

##### 安装Docker
```bash
# 更新系统
sudo yum update -y

# 安装Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 重新登录或执行以下命令
newgrp docker

# 验证Docker安装
docker --version
```

##### 安装Docker Compose
```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 赋予执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 创建软链接
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 验证安装
docker-compose --version
```

##### 配置防火墙
```bash
# 开放必要端口
sudo firewall-cmd --permanent --add-port=5001/tcp  # 后端API
sudo firewall-cmd --permanent --add-port=80/tcp    # 前端
sudo firewall-cmd --permanent --add-port=8080/tcp  # Nginx（可选）

# 重载防火墙配置
sudo firewall-cmd --reload

# 查看开放的端口
sudo firewall-cmd --list-ports
```

#### 3. 文件传输方案

##### 方案一：使用SCP/SFTP
```bash
# 在Windows上使用WinSCP或FileZilla
# 或在CentOS上使用scp命令
scp -r /path/to/behavior_identify user@centos-ip:/home/user/
```

##### 方案二：使用共享文件夹
```bash
# VMware共享文件夹
# 1. 在VMware中设置共享文件夹
# 2. 在CentOS中挂载
sudo mkdir /mnt/shared
sudo mount -t fuse.vmhgfs-fuse .host:/ /mnt/shared -o allow_other

# 复制项目文件
cp -r /mnt/shared/behavior_identify /home/user/
```

##### 方案三：使用Git
```bash
# 在CentOS中安装Git
sudo yum install -y git

# 克隆项目（如果有Git仓库）
git clone <repository-url>
cd behavior_identify
```

#### 4. 网络配置

##### 获取虚拟机IP地址
```bash
# 查看IP地址
ip addr show
# 或
ifconfig
```

##### 配置端口转发（VMware）
1. 虚拟机设置 → 网络适配器 → NAT设置
2. 添加端口转发规则：
   - 主机端口5001 → 虚拟机端口5001
   - 主机端口80 → 虚拟机端口80

## 🚀 部署步骤

### 快速部署（单容器）

1. **准备环境**
```bash
# 进入项目目录
cd /home/user/behavior_identify

# 确保模型文件存在
ls yolo_slowfast-master/*.pt
ls yolo_slowfast-master/*.pyth

# 如果模型文件缺失，需要从Windows传输或下载
```

2. **构建并运行**
```bash
# 赋予脚本执行权限
chmod +x deploy.sh manage.sh docker-entrypoint.sh

# 一键部署
./deploy.sh

# 或手动构建
docker build -t behavior-detection .

# 手动运行容器
docker run -d \
  --name behavior-detection \
  -p 5001:5001 \
  -v $(pwd)/uploads:/app/uploads \
  -v $(pwd)/outputs:/app/outputs \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/database:/app/database \
  behavior-detection
```

3. **Windows访问配置**
```bash
# 在CentOS中查看容器状态
docker ps

# 查看容器日志
docker logs behavior-detection

# 在Windows浏览器中访问
# http://虚拟机IP:5001  (后端API)
# http://虚拟机IP:80    (前端界面，如果使用多容器部署)
```

### 生产部署（多容器）

1. **准备配置文件**
```bash
# 创建环境变量文件
cat > .env << EOF
FLASK_ENV=production
DATABASE_URL=sqlite:///database/behavior_detection.db
EOF
```

2. **启动服务**
```bash
# 使用Docker Compose启动
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

## 🔧 高级配置

### GPU支持（可选）

如需GPU加速，修改docker-compose.yml：

```yaml
services:
  backend:
    # ... 其他配置
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
```

### 数据持久化

```yaml
volumes:
  database_data:
    driver: local
  uploads_data:
    driver: local
  outputs_data:
    driver: local

services:
  backend:
    volumes:
      - database_data:/app/database
      - uploads_data:/app/uploads  
      - outputs_data:/app/outputs
```

## 📊 监控和维护

### 健康检查

```yaml
services:
  backend:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 日志管理

```yaml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## 🔍 故障排除

### Windows + CentOS 特有问题

1. **虚拟机网络问题**
   ```bash
   # 检查虚拟机网络配置
   ip route show

   # 测试网络连通性
   ping 8.8.8.8

   # 检查端口监听
   netstat -tlnp | grep :5001
   ```

2. **文件权限问题**
   ```bash
   # 修复文件权限
   sudo chown -R $USER:$USER /home/user/behavior_identify
   chmod -R 755 /home/user/behavior_identify

   # 修复Docker相关权限
   sudo chmod 666 /var/run/docker.sock
   ```

3. **防火墙阻止访问**
   ```bash
   # 临时关闭防火墙测试
   sudo systemctl stop firewalld

   # 或添加具体规则
   sudo firewall-cmd --permanent --add-port=5001/tcp
   sudo firewall-cmd --reload
   ```

4. **虚拟机资源不足**
   ```bash
   # 检查系统资源
   free -h        # 内存使用
   df -h          # 磁盘使用
   top            # CPU使用

   # 清理Docker资源
   docker system prune -a
   ```

### 常见问题

1. **模型文件缺失**
   ```bash
   # 检查模型文件
   ls -la yolo_slowfast-master/*.pt
   ls -la yolo_slowfast-master/*.pyth

   # 如果缺失，从Windows传输
   # 使用WinSCP或共享文件夹方式
   ```

2. **端口冲突**
   ```bash
   # 检查端口占用
   sudo netstat -tlnp | grep :5001
   sudo netstat -tlnp | grep :80

   # 修改端口配置
   vim .env  # 修改BACKEND_PORT和FRONTEND_PORT
   ```

3. **内存不足**
   ```bash
   # 增加虚拟机内存（在VMware中设置）
   # 或限制Docker容器内存使用
   docker run --memory="2g" ...
   ```

4. **权限问题**
   ```bash
   # 确保目录权限正确
   sudo chown -R $USER:docker uploads outputs logs database
   chmod 755 uploads outputs logs database
   ```

5. **Windows无法访问虚拟机服务**
   ```bash
   # 检查虚拟机IP
   hostname -I

   # 检查服务是否启动
   docker ps
   curl http://localhost:5001/api/health

   # 配置VMware端口转发或使用桥接网络
   ```

### 调试命令

```bash
# 进入容器调试
docker exec -it behavior-backend bash

# 查看容器日志
docker logs behavior-backend
docker logs -f behavior-backend  # 实时查看

# 检查网络连接
docker network ls
docker network inspect behavior_behavior-network

# 在CentOS中测试服务
curl http://localhost:5001/api/health
curl http://虚拟机IP:5001/api/health

# 从Windows测试（在Windows命令行中）
curl http://虚拟机IP:5001/api/health
# 或在浏览器中访问 http://虚拟机IP:5001/api/health
```

### Windows + CentOS 部署最佳实践

1. **网络配置建议**
   - 使用桥接网络模式，虚拟机获得独立IP
   - 或使用NAT模式 + 端口转发
   - 确保Windows防火墙允许相关端口

2. **文件同步建议**
   - 开发阶段：使用共享文件夹实时同步
   - 部署阶段：使用SCP/SFTP传输完整项目
   - 生产阶段：使用Git进行版本控制

3. **资源分配建议**
   - 虚拟机内存：至少4GB（AI模型需要较多内存）
   - 虚拟机硬盘：至少50GB（包含模型文件和数据）
   - CPU核心：至少2核（提升构建和运行速度）

4. **备份策略**
   ```bash
   # 定期备份虚拟机快照
   # 备份项目数据
   ./manage.sh backup

   # 备份Docker镜像
   docker save behavior-detection > behavior-detection.tar
   ```

## 📝 部署清单

- [ ] 确认所有依赖文件完整
- [ ] 检查模型文件存在
- [ ] 配置环境变量
- [ ] 创建数据卷
- [ ] 测试网络连通性
- [ ] 验证API接口
- [ ] 检查WebSocket连接
- [ ] 测试文件上传功能
- [ ] 验证实时监控功能

## 🎯 性能优化建议

1. **镜像优化**
   - 使用多阶段构建减小镜像大小
   - 清理不必要的依赖和缓存

2. **资源配置**
   - 根据实际需求调整内存和CPU限制
   - 考虑使用GPU加速

3. **网络优化**
   - 使用CDN加速静态资源
   - 配置适当的缓存策略

4. **存储优化**
   - 定期清理临时文件
   - 使用外部存储服务

## 📦 完整配置文件

### 1. 根目录Dockerfile（单容器方案）

```dockerfile
# 文件名: Dockerfile
# 多阶段构建 - 前端构建阶段
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install --registry=https://registry.npmmirror.com
COPY frontend/ ./
RUN npm run build

# 主应用阶段 - Python环境
FROM python:3.9-slim

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc g++ \
    libglib2.0-0 libsm6 libxext6 libxrender-dev \
    libgomp1 libgtk-3-0 libgl1-mesa-glx \
    curl wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制依赖文件
COPY backend/requirements.txt ./backend/
COPY yolo_slowfast-master/requirements.txt ./yolo_slowfast-master/

# 安装Python依赖（使用清华镜像源）
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple \
    -r backend/requirements.txt \
    -r yolo_slowfast-master/requirements.txt

# 复制应用代码
COPY backend/ ./backend/
COPY yolo_slowfast-master/ ./yolo_slowfast-master/

# 复制前端构建结果
COPY --from=frontend-builder /app/frontend/dist ./static/

# 创建必要目录并设置权限
RUN mkdir -p uploads outputs logs database && \
    chmod 755 uploads outputs logs database

# 设置环境变量
ENV PYTHONPATH=/app
ENV FLASK_APP=backend/app.py
ENV FLASK_ENV=production
ENV ENABLE_GUI=false

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5001/api/health || exit 1

# 暴露端口
EXPOSE 5001

# 启动脚本
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
```

### 2. 启动脚本

```bash
#!/bin/bash
# 文件名: docker-entrypoint.sh

set -e

echo "🚀 启动智能行为检测系统..."

# 检查必要的目录
echo "📁 检查目录结构..."
mkdir -p /app/uploads /app/outputs /app/logs /app/database

# 检查模型文件
echo "🧠 检查AI模型文件..."
if [ ! -f "/app/yolo_slowfast-master/yolov8n.pt" ]; then
    echo "⚠️  警告: YOLOv8模型文件不存在"
fi

if [ ! -f "/app/yolo_slowfast-master/SLOWFAST_8x8_R50_DETECTION.pyth" ]; then
    echo "⚠️  警告: SlowFast模型文件不存在"
fi

# 初始化数据库
echo "🗄️  初始化数据库..."
cd /app && python -c "
from backend.models.database import create_tables
from backend.app import create_app
app = create_app('production')
with app.app_context():
    create_tables()
    print('数据库初始化完成')
"

# 启动应用
echo "🎯 启动Flask应用..."
cd /app
exec python backend/app.py
```

### 3. Docker Compose完整配置

```yaml
# 文件名: docker-compose.yml
version: '3.8'

services:
  # 后端服务
  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    container_name: behavior-backend
    restart: unless-stopped
    ports:
      - "${BACKEND_PORT:-5001}:5001"
    volumes:
      - uploads_data:/app/uploads
      - outputs_data:/app/outputs
      - logs_data:/app/logs
      - database_data:/app/database
      - ./yolo_slowfast-master:/app/yolo_slowfast-master:ro
    environment:
      - FLASK_ENV=${FLASK_ENV:-production}
      - PYTHONPATH=/app
      - ENABLE_GUI=false
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - behavior-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # 前端服务
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: behavior-frontend
    restart: unless-stopped
    ports:
      - "${FRONTEND_PORT:-80}:80"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - behavior-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Nginx反向代理（可选）
  nginx:
    image: nginx:alpine
    container_name: behavior-nginx
    restart: unless-stopped
    ports:
      - "${NGINX_PORT:-8080}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - backend
      - frontend
    networks:
      - behavior-network
    profiles:
      - with-nginx

networks:
  behavior-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  uploads_data:
    driver: local
  outputs_data:
    driver: local
  logs_data:
    driver: local
  database_data:
    driver: local
```

### 4. 环境变量配置

```bash
# 文件名: .env
# 基础配置
COMPOSE_PROJECT_NAME=behavior-detection
FLASK_ENV=production

# 端口配置
BACKEND_PORT=5001
FRONTEND_PORT=80
NGINX_PORT=8080

# 数据库配置
DATABASE_URL=sqlite:///database/behavior_detection.db

# AI模型配置
DEVICE=cpu
CONFIDENCE_THRESHOLD=0.5
IOU_THRESHOLD=0.4

# 文件上传配置
MAX_CONTENT_LENGTH=500MB
UPLOAD_FOLDER=/app/uploads
OUTPUT_FOLDER=/app/outputs

# 日志配置
LOG_LEVEL=INFO
LOG_FILE=/app/logs/app.log

# 时区配置
TZ=Asia/Shanghai
```

### 5. 后端专用Dockerfile

```dockerfile
# 文件名: backend/Dockerfile
FROM python:3.9-slim

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc g++ \
    libglib2.0-0 libsm6 libxext6 libxrender-dev \
    libgomp1 libgtk-3-0 libgl1-mesa-glx \
    curl wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制依赖文件并安装
COPY requirements.txt ../yolo_slowfast-master/requirements.txt ./
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple \
    -r requirements.txt

# 复制应用代码
COPY . ./backend/
COPY ../yolo_slowfast-master ./yolo_slowfast-master/

# 创建必要目录
RUN mkdir -p uploads outputs logs database

# 设置环境变量
ENV PYTHONPATH=/app
ENV FLASK_APP=backend/app.py
ENV FLASK_ENV=production
ENV ENABLE_GUI=false

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5001/api/health || exit 1

EXPOSE 5001

CMD ["python", "backend/app.py"]
```

### 6. 前端专用Dockerfile

```dockerfile
# 文件名: frontend/Dockerfile
# 构建阶段
FROM node:18-alpine AS builder

WORKDIR /app

# 复制依赖文件
COPY package*.json ./
RUN npm install --registry=https://registry.npmmirror.com

# 复制源代码并构建
COPY . .
RUN npm run build

# 生产阶段
FROM nginx:alpine

# 复制构建结果
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制Nginx配置
COPY nginx.conf /etc/nginx/nginx.conf

# 设置时区
RUN apk add --no-cache tzdata
ENV TZ=Asia/Shanghai

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 7. Nginx配置文件

```nginx
# 文件名: frontend/nginx.conf
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript
               application/javascript application/xml+rss
               application/json;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # 安全头
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # 前端路由
        location / {
            try_files $uri $uri/ /index.html;
        }

        # 静态资源缓存
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API代理
        location /api/ {
            proxy_pass http://behavior-backend:5001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # 超时设置
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # WebSocket代理
        location /socket.io/ {
            proxy_pass http://behavior-backend:5001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # 视频流代理
        location /video_feed {
            proxy_pass http://behavior-backend:5001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # 视频流特殊设置
            proxy_buffering off;
            proxy_cache off;
        }

        # 文件上传大小限制
        client_max_body_size 500M;
    }
}
```

## 🛠️ 部署脚本

### 1. 一键部署脚本

```bash
#!/bin/bash
# 文件名: deploy.sh

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

# 生成配置文件
generate_config() {
    echo -e "${YELLOW}⚙️  生成配置文件...${NC}"

    if [ ! -f ".env" ]; then
        cat > .env << EOF
# 智能行为检测系统 - Docker环境配置
COMPOSE_PROJECT_NAME=behavior-detection
FLASK_ENV=production

# 端口配置
BACKEND_PORT=5001
FRONTEND_PORT=80
NGINX_PORT=8080

# 数据库配置
DATABASE_URL=sqlite:///database/behavior_detection.db

# AI模型配置
DEVICE=cpu
CONFIDENCE_THRESHOLD=0.5
IOU_THRESHOLD=0.4

# 文件配置
MAX_CONTENT_LENGTH=500MB
UPLOAD_FOLDER=/app/uploads
OUTPUT_FOLDER=/app/outputs

# 日志配置
LOG_LEVEL=INFO
LOG_FILE=/app/logs/app.log

# 时区配置
TZ=Asia/Shanghai
EOF
        echo "生成 .env 配置文件"
    fi

    echo -e "${GREEN}✅ 配置文件生成完成${NC}"
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
    generate_config
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
```

### 2. 管理脚本

```bash
#!/bin/bash
# 文件名: manage.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示帮助信息
show_help() {
    echo "智能行为检测系统 - 管理脚本"
    echo "用法: ./manage.sh [命令]"
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
    echo ""
}

# 启动服务
start_services() {
    echo -e "${YELLOW}🚀 启动服务...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✅ 服务启动完成${NC}"
}

# 停止服务
stop_services() {
    echo -e "${YELLOW}⏹️  停止服务...${NC}"
    docker-compose down
    echo -e "${GREEN}✅ 服务停止完成${NC}"
}

# 重启服务
restart_services() {
    echo -e "${YELLOW}🔄 重启服务...${NC}"
    docker-compose restart
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
        *)
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"
```

### 3. 开发环境脚本

```bash
#!/bin/bash
# 文件名: dev.sh

set -e

echo "🛠️  智能行为检测系统 - 开发环境"

# 启动开发环境
start_dev() {
    echo "启动开发环境..."

    # 启动后端
    echo "启动后端服务..."
    cd backend
    python app.py &
    BACKEND_PID=$!
    cd ..

    # 启动前端
    echo "启动前端服务..."
    cd frontend
    npm run serve &
    FRONTEND_PID=$!
    cd ..

    echo "开发环境启动完成"
    echo "后端PID: $BACKEND_PID"
    echo "前端PID: $FRONTEND_PID"
    echo "前端地址: http://localhost:8080"
    echo "后端地址: http://localhost:5001"

    # 等待用户输入停止
    read -p "按Enter键停止开发环境..."

    # 停止服务
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    echo "开发环境已停止"
}

# 安装依赖
install_deps() {
    echo "安装项目依赖..."

    # 安装后端依赖
    echo "安装后端依赖..."
    cd backend
    pip install -r requirements.txt
    cd ..

    # 安装前端依赖
    echo "安装前端依赖..."
    cd frontend
    npm install
    cd ..

    echo "依赖安装完成"
}

# 运行测试
run_tests() {
    echo "运行测试..."

    # 后端测试
    echo "运行后端测试..."
    cd backend
    python -m pytest tests/ || echo "后端测试完成"
    cd ..

    # 前端测试
    echo "运行前端测试..."
    cd frontend
    npm run test || echo "前端测试完成"
    cd ..
}

case "$1" in
    start)
        start_dev
        ;;
    install)
        install_deps
        ;;
    test)
        run_tests
        ;;
    *)
        echo "用法: ./dev.sh [start|install|test]"
        ;;
esac
```

## 📋 部署检查清单

### 部署前检查
- [ ] Docker和Docker Compose已安装
- [ ] 项目代码完整下载
- [ ] AI模型文件存在（yolov8n.pt, SLOWFAST_8x8_R50_DETECTION.pyth等）
- [ ] 端口5001和80未被占用
- [ ] 磁盘空间充足（建议至少10GB）

### 部署过程检查
- [ ] 执行 `chmod +x deploy.sh` 赋予执行权限
- [ ] 运行 `./deploy.sh` 进行一键部署
- [ ] 检查所有容器状态为 `Up`
- [ ] 访问健康检查接口返回正常

### 部署后验证
- [ ] 前端页面正常加载
- [ ] 后端API响应正常
- [ ] WebSocket连接正常
- [ ] 文件上传功能正常
- [ ] 视频检测功能正常
- [ ] 实时监控功能正常

---

**部署完成后访问地址**：
- 前端界面：http://localhost (或配置的端口)
- 后端API：http://localhost:5001
- 健康检查：http://localhost:5001/api/health

**管理命令**：
```bash
# 查看服务状态
./manage.sh status

# 查看日志
./manage.sh logs

# 重启服务
./manage.sh restart

# 备份数据
./manage.sh backup
```
