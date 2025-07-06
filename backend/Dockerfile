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
