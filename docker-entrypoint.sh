#!/bin/bash

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
