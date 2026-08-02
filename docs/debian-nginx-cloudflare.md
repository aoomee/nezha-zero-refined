# Debian + Nginx + Cloudflare 单端口 gRPC

本文对应 Nezha Zero Refined 的默认单端口设计：网页与 Agent 都使用 `10086`。

将文中的 `nezha.example.com` 全部替换成你的真实域名。

## 1. 准备域名

在 Cloudflare 添加一条 A 记录，指向服务器公网 IP。首次申请证书时，先把这条记录设为灰色云（仅 DNS）。

## 2. 安装面板

以 root 用户执行：

```bash
curl -fsSL https://raw.githubusercontent.com/aoomee/nezha-zero-refined/main/install.sh | sh
```

脚本会显示管理员密码。面板本机地址为 `http://127.0.0.1:10086`。

## 3. 安装 Nginx 与证书

```bash
apt update
apt install -y nginx certbot python3-certbot-nginx
certbot --nginx -d nezha.example.com
```

创建 `/etc/nginx/conf.d/nezha.example.com.conf`：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name nezha.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name nezha.example.com;

    ssl_certificate /etc/letsencrypt/live/nezha.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nezha.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location ^~ /proto.NezhaService/ {
        grpc_pass grpc://127.0.0.1:10086;
        grpc_set_header Host $host;
        grpc_set_header nz-realip $http_cf_connecting_ip;
        grpc_set_header client_secret $http_client_secret;
        grpc_set_header client_uuid $http_client_uuid;
        client_body_timeout 3600s;
        grpc_read_timeout 3600s;
        grpc_send_timeout 3600s;
        grpc_socket_keepalive on;
    }

    location / {
        proxy_pass http://127.0.0.1:10086;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $http_cf_connecting_ip;
        proxy_set_header X-Forwarded-For $http_cf_connecting_ip;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

验证并重载：

```bash
nginx -t
systemctl reload nginx
```

## 4. 让 Agent 使用 HTTPS 443

登录 `https://nezha.example.com`，进入设置：

1. 将“未接入 CDN 的面板服务器域名/IP”填为 `nezha.example.com`；
2. 在服务器的 `/opt/nezha-zero-refined/data/config.yaml` 顶层加入（若已存在则修改，不要重复）：

```yaml
proxygrpcport: 443
tls: true
```

3. 重启面板：

```bash
cd /opt/nezha-zero-refined
docker compose --env-file .env -f compose.refined.yaml up -d
```

## 5. Cloudflare

将 DNS 改回橙色云，并在 Cloudflare 中设置：

- SSL/TLS：完全（严格）
- 网络：开启 gRPC

完成后，网页访问 `https://nezha.example.com`；Agent 通过同一个域名的 443 端口接入。
