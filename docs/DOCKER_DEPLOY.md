# Docker 部署 / 安全试跑

这套 Docker 配置用于在 Linux 上隔离运行项目，避免改动宿主机的 `systemd`、`/usr/local/bin`、`/home/workspace` 等线上环境。

默认模式是 **dashboard only**：只启动 Xvfb 和 Web 面板，不会自动开始注册批次。

## 1. 准备

```bash
git clone https://github.com/xingluoyuankong/outlook-auto-register.git
cd outlook-auto-register

cp .env.docker.example .env
mkdir -p docker-data/mihomo_runtime docker-data/runtime_outlook docker-data/xray_runtime docker-data/cloud-register-email
```

如果有代理订阅，可以二选一：

方式 A：编辑 `.env`：

```bash
SUBSCRIPTION_URL="https://your-subscription-url"
```

方式 B：手动写入 JSON：

```bash
cat > docker-data/mihomo_runtime/subscriptions.json <<'JSON'
[
  {
    "name": "default",
    "url": "https://your-subscription-url"
  }
]
JSON
```

## 2. 构建

```bash
docker compose build
```

## 3. 启动面板，安全观察

```bash
docker compose up -d
docker compose logs -f
```

面板地址：

```text
http://127.0.0.1:8765/
```

默认 compose 只绑定 `127.0.0.1`，不会公网暴露。如果在远程服务器上测试，用 SSH 隧道访问：

```bash
ssh -L 8765:127.0.0.1:8765 user@server
```

## 4. 手动执行一次状态检查

```bash
docker compose exec outlook-auto-register python 邮箱注册/xray_proxy.py status
docker compose exec outlook-auto-register python outlook_launcher.py status
```

## 5. 手动试跑一次

先建议不抓 RT：

```bash
docker compose exec outlook-auto-register python outlook_launcher.py run --count 1 --shuffle --no-rt
```

查看结果：

```bash
tail -f docker-data/runtime_outlook/logs/outlook_daemon.log
cat docker-data/runtime_outlook/results.jsonl
```

## 6. 明确开启守护模式

守护模式会运行 `outlook_daemon.py`，启动后可能按计划自动执行注册批次：

```bash
APP_MODE=daemon docker compose up -d --force-recreate
docker compose logs -f
```

切回安全面板模式：

```bash
APP_MODE=dashboard docker compose up -d --force-recreate
```

## 7. 停止和清理

停止容器：

```bash
docker compose down
```

连运行数据一起删除：

```bash
docker compose down
rm -rf docker-data
```

## 8. 隔离范围

- 不安装宿主机 `systemd` 服务
- 不修改宿主机 `/usr/local/bin`
- 不启动宿主机 Xvfb
- 面板默认只监听宿主机 `127.0.0.1:8765`
- 所有运行数据在 `docker-data/`
- Chrome 运行在容器内，使用 `--no-sandbox` 和容器独立 `/tmp`

## 9. 常用命令

```bash
# 进入容器 shell
docker compose exec outlook-auto-register bash

# 查看容器内进程
docker compose exec outlook-auto-register ps aux

# 查看监听端口
docker compose exec outlook-auto-register ss -tlnp

# 查看 xray 状态
docker compose exec outlook-auto-register python 邮箱注册/xray_proxy.py status

# 刷新 xray 订阅
docker compose exec outlook-auto-register python 邮箱注册/xray_proxy.py refresh

# 手动注册 1 个
docker compose exec outlook-auto-register python outlook_launcher.py run --count 1 --shuffle --no-rt

# 手动注册 5 个
docker compose exec outlook-auto-register python outlook_launcher.py run --count 5 --shuffle
```

## 10. 阿里云 ACR 自动构建后拉取部署

如果镜像已经由阿里云 Container Registry 自动构建，例如：

```text
registry.cn-hangzhou.aliyuncs.com/jiangshitong/outlook-auto-register:latest
```

服务器上不需要 `Dockerfile` 构建，只需要 `docker-compose.aliyun.yml` 和 `.env`。

```bash
mkdir -p /www/docker/outlook-auto-register
cd /www/docker/outlook-auto-register

# 放置 docker-compose.aliyun.yml 和 .env
# 可以从仓库复制：
#   docker-compose.aliyun.yml
#   .env.aliyun.example -> .env

docker login --username='蒋世彤' registry.cn-hangzhou.aliyuncs.com
docker compose -f docker-compose.aliyun.yml pull
docker compose -f docker-compose.aliyun.yml up -d
docker compose -f docker-compose.aliyun.yml logs -f
```

默认 `.env.aliyun.example` 使用：

```bash
APP_MODE=dashboard
HOST_BIND_ADDR=127.0.0.1
APP_PORT=8765
APP_DATA_DIR=/www/docker/outlook-auto-register
```

这表示只启动面板，并且只允许服务器本机访问 `127.0.0.1:8765`。远程访问可用 SSH 隧道：

```bash
ssh -L 8765:127.0.0.1:8765 user@server
```

如果确认要开启自动守护注册：

```bash
sed -i 's/^APP_MODE=.*/APP_MODE=daemon/' .env
docker compose -f docker-compose.aliyun.yml up -d --force-recreate
```
