<div align="center">
  <img width="340" src="resource/static/brand.svg" alt="Nezha Monitoring">

# Nezha Zero Refined

柔和、简约、响应式的哪吒 V0 美化发行版。<br>
保留 `railzen/nezha-zero` 的完整功能，并自动跟随上游更新。

[![Refined CI](https://github.com/aoomee/nezha-zero-refined/actions/workflows/refined-ci.yml/badge.svg)](https://github.com/aoomee/nezha-zero-refined/actions/workflows/refined-ci.yml)
[![Publish image](https://github.com/aoomee/nezha-zero-refined/actions/workflows/refined-image.yml/badge.svg)](https://github.com/aoomee/nezha-zero-refined/actions/workflows/refined-image.yml)
[![Sync upstream](https://github.com/aoomee/nezha-zero-refined/actions/workflows/sync-upstream.yml/badge.svg)](https://github.com/aoomee/nezha-zero-refined/actions/workflows/sync-upstream.yml)
[![License](https://img.shields.io/github/license/aoomee/nezha-zero-refined)](LICENSE)

![Nezha Zero Refined 首页预览](docs/images/preview.jpg)
</div>

## 这是什么

Nezha Zero Refined 是 [railzen/nezha-zero](https://github.com/railzen/nezha-zero) 的非官方美化发行版。它保留上游 Dashboard、Agent、数据库、API、WebSocket、gRPC、登录、告警、任务、终端等功能，只在最后加载一层独立 CSS，重新设计默认前台、登录页和管理后台的视觉表现。

本项目追求三件事：

- **功能不变**：不改 Go、JavaScript、API、数据库结构或 Agent 协议。
- **开箱即用**：提供多架构容器镜像、自动生成安全凭据和 Docker Compose 部署。
- **持续跟随上游**：每天合并上游 `main`；只有边界检查、Dashboard 测试、Agent 测试和构建全部通过才会发布。

## 设计特点

- 柔和的灰绿中性色，不刺眼、不堆叠高饱和装饰。
- 卡片、表格、表单、弹窗、导航和后台页面保持统一。
- 自动跟随系统浅色/深色模式。
- 4 / 3 / 2 / 1 列响应式服务器卡片，适配桌面、平板和手机。
- 清晰的在线、警告、故障和离线状态，不牺牲信息密度。
- 完整键盘焦点样式、44px 移动端触控目标和减少动效支持。
- 不加载新的外部字体或前端运行时。

## 30 秒部署

需要已安装 Docker Engine 与支持 `up --wait` 的较新 Docker Compose v2。

```bash
git clone https://github.com/aoomee/nezha-zero-refined.git
cd nezha-zero-refined
./refined-install.sh
```

脚本会：

1. 生成仅当前用户可读的 `.env`；
2. 随机生成管理员密码和 Agent 发现密钥；
3. 拉取 `amd64`、`arm64` 或 `s390x` 对应镜像；
4. 启动 Dashboard，并在终端中显示首次登录信息。

默认访问地址为 `http://服务器IP:8008`，默认管理员为 `admin`。首次输出的密码也会保存在 `.env`，请妥善保管。

> 公网部署前，请配置反向代理与 HTTPS，并只开放实际需要的端口。Dashboard HTTP 默认映射为 `8008`，Agent gRPC 默认映射为 `5555`。

## 更新

```bash
cd nezha-zero-refined
./refined-update.sh
```

更新前，脚本会停止 Dashboard 并将一致的数据快照保存到 `./backups`。新容器必须在 180 秒内通过健康检查；否则脚本会恢复旧镜像与旧数据，并把失败版本的数据留在 `data.failed.*` 供排查。

## 自定义部署参数

安装脚本生成的 `.env` 包含以下配置：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `REFINED_IMAGE` | `ghcr.io/aoomee/nezha-zero-refined:latest` | 要部署的镜像，可固定到 `sha-*` |
| `NZ_ADMIN` | `admin` | 密码登录管理员用户名 |
| `NZ_ADMIN_PASSWORD` | 自动生成 | 管理员密码 |
| `NZ_SITE_NAME` | `Nezha Monitoring` | 站点名称 |
| `NZ_HTTP_PORT` | `8008` | 主机 HTTP 端口 |
| `NZ_GRPC_PORT` | `5555` | 主机 Agent gRPC 端口 |
| `NZ_GRPC_HOST` | 空 | Agent 连接的公网域名或 IP |
| `NZ_GRPC_SECRET` | 自动生成 | Agent 自动发现密钥 |
| `TZ` | `Asia/Shanghai` | 时区 |

`REFINED_IMAGE`、`NZ_HTTP_PORT` 和 `NZ_GRPC_PORT` 是持续生效的部署参数。其余 `NZ_*` 值用于空数据目录的首次引导；首次启动后，`data/config.yaml` 是应用配置的事实来源，请在 Dashboard 设置页修改站点、登录和 Agent 参数。

也可以手动部署：

```bash
cp .env.example .env
# 编辑 .env，替换所有 Change-* 示例值
docker compose --env-file .env -f compose.refined.yaml up -d
```

Agent 的域名、TLS 和代理端口仍在 Dashboard 的设置页配置，行为与上游一致。

## 从现有 Nezha Zero 迁移

本项目使用完整上游代码和相同的数据目录格式。迁移前请先停止旧容器并备份原来的 `data` 目录，然后将其复制到本项目根目录：

```bash
docker compose down
cp -a /path/to/old-nezha/data ./data
./refined-install.sh
```

不要同时让新旧 Dashboard 写入同一个 SQLite 数据库。若来源版本较旧，建议先阅读 [上游文档](https://railzen.github.io/nezha-zero) 与发布说明。

## 如何保证功能性不变

Refined 的运行时代码与上游相同。视觉改动被限制在三个位置：

| 层 | 文件 | 作用 |
| --- | --- | --- |
| 前台入口 | `resource/template/theme-default/header.html` | 在上游样式之后加载 Refined CSS |
| 公共入口 | `resource/template/common/header.html` | 让登录页与管理后台加载同一视觉层 |
| 视觉层 | `resource/static/refined/refined.css` | 颜色、间距、圆角、排版和响应式布局 |

没有修改：

- Dashboard 或 Agent 的 Go 代码；
- Vue、jQuery、WebSocket 与监控图表逻辑；
- API、gRPC、Proto、数据库模型和迁移；
- 登录加密、CSRF、表单字段、通知、任务与终端逻辑。

CI 会分别执行：

```bash
go test ./...
go build ./cmd/dashboard
(cd agent && go test -skip TestCloudflareDetection ./...)
(cd agent && go build ./cmd/agent)
```

此外，[边界守卫](scripts/verify-refined-boundary.sh) 会阻止自动同步意外改动 Refined 允许范围以外的文件。

## 如何跟随上游，同时保护美化

每天的 [Sync upstream](.github/workflows/sync-upstream.yml) 工作流会：

1. 获取 `railzen/nezha-zero:main`；
2. 创建普通 Git 合并，保留上游完整历史；
3. 验证 Refined 样式入口和代码边界；
4. 测试并构建 Dashboard；
5. 单独测试 Agent 模块；
6. 构建容器并真实启动，检查首页与 Refined 静态资源；
7. 仅在全部成功后推送 `main`，随后发布新镜像。

如果上游改动与视觉层冲突，或任何测试失败，工作流不会强行覆盖文件，也不会推送半成品；它会创建带有 `upstream-sync` 标签的 Issue，等待人工适配。若源码推送后仅镜像发布遇到临时故障，下次定时任务会识别缺少的 `sha-*` 镜像并重试。这样可以同时获得上游修复与稳定的 Refined 设计。

当前 Refined 初始基线为上游提交 [`fceac6e`](https://github.com/railzen/nezha-zero/commit/fceac6ed1425cf6ab254c3e2a92b21f58897de06)。

## 本地开发

需要 Go `1.26.x`。

```bash
go test ./...
go build ./cmd/dashboard
./scripts/verify-refined-boundary.sh
```

所有 UI 调整应继续放在 `resource/static/refined/`，不要复制或重写上游业务模板。这样能显著降低后续同步冲突。

## 上游、致谢与许可证

本项目不是哪吒监控官方发行版。核心功能、安装脚本与原始主题来自：

- [railzen/nezha-zero](https://github.com/railzen/nezha-zero)
- [nezhahq/nezha](https://github.com/nezhahq/nezha)
- 上游 README 中列出的主题与兼容 API 贡献者

项目继续遵循 [Apache License 2.0](LICENSE)。使用与分发时请保留原始许可证和上游署名。
