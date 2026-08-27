# Hermes Studio fnOS 原生应用开发文档

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 应用名称 | Hermes Studio |
| 建议包名 | `HermesStudio` |
| 建议仓库名 | `HermesStudio-fnOS` |
| 初始版本 | `0.1.0` |
| 目标系统 | 飞牛 fnOS 1.2 最新正式版及以上 |
| 目标架构 | 仅 x86_64（manifest 使用 `platform=x86`） |
| 交付形式 | 单个原生 FPK，不依赖 Docker |
| 使用范围 | 仅个人使用，不公开分发、不提交应用中心 |
| 上游项目 | NousResearch/hermes-agent、EKKOLearnAI/hermes-studio |

## 2. 项目目标

把 Hermes Agent 与 Hermes Studio 合并为一个飞牛原生应用：

- Hermes Agent 作为后台 Agent 运行时、消息网关、Skills、记忆、MCP、定时任务和工具执行核心。
- Hermes Studio 作为 Hermes Agent 唯一的 WebUI，负责聊天、会话、模型/API、任务、消息平台、文件、终端、浏览器和工作流管理。
- 应用关闭网页后继续在后台运行，持续接收微信、QQ、Telegram 等平台消息并执行定时任务。
- 所有运行时和程序依赖全部打入 FPK，安装过程中不联网下载 Python、Node.js、Chromium、npm 或 Python 依赖。
- 安装后允许用户配置模型 API、消息平台凭证和 MCP；这些外部服务本身仍需联网。

## 3. 已确认需求

### 3.1 必须支持

- Studio 网页聊天与会话管理。
- 模型、Provider 和 API Key 管理。
- Hermes Agent 的 Skills、记忆和 MCP。
- 定时任务、可视化工作流和后台执行。
- 上游全部消息平台配置能力。
- 重点完整验收：
  - 个人微信扫码登录；
  - QQ 开放平台机器人；
  - Telegram Bot。
- 文件浏览、上传、下载、编辑和预览。
- Web 终端。
- Agent 浏览器控制：
  - 优先连接飞牛应用中心安装的 Chrome；
  - 无法连接时自动启动内置 Chromium。
- 关闭浏览器页面后，Agent、消息网关和定时任务继续运行。
- 仅访问用户授权的 NAS 目录。
- 普通命令可执行，危险命令必须人工确认。
- 单管理员使用。
- GitHub Actions 只跟踪两个上游的正式 Release，自动构建新版 FPK，由用户手动覆盖升级。
- 覆盖升级保留所有配置、会话、Skills、记忆、任务、机器人登录凭证和浏览器 Profile。

### 3.2 不包含

- Docker 或 Docker Compose 运行方式。
- ARM64 构建。
- 现有 Docker 数据自动迁移。
- 公网直接开放和公网部署支持。
- 语音输入、STT、TTS、实时语音舞台及离线语音模型。
- Ekko、Claude Code、Codex、Pi 等其他 Agent。
- 应用运行中的自更新；更新只能通过新版 FPK 完成。
- 本地大模型本体。可连接局域网或互联网中的 OpenAI 兼容模型接口。

## 4. 架构决策

### 4.1 采用单一 FPK

Hermes Agent 和 Hermes Studio 合并进一个 `HermesStudio.fpk`，不拆成两个应用。

原因：

- Studio 官方部署本来就会发现并调用 Hermes Agent 源码、CLI、Agent Bridge 和 Gateway。
- 合并后不需要跨 FPK 共享 Python 环境、Hermes Home、Socket、密钥和文件 ACL。
- 启停、升级、日志、备份和健康检查只需维护一个生命周期。
- Studio 可以直接使用固定的内置 Agent 路径，不需要探测另一个应用是否安装或正在运行。
- 用户只看到一个桌面图标和一个应用设置项，操作最简单。

### 4.2 运行关系

```text
飞牛桌面入口
    │
    ▼
Hermes Studio WebUI（0.0.0.0:8648）
    │
    ├── Studio Koa/Socket.IO 服务
    ├── Hermes Agent Bridge（本机 Unix Socket）
    ├── Hermes Gateway（后台消息平台）
    ├── Cron / Workflow / MCP
    └── Browser Adapter
          ├── 飞牛应用中心 Chrome（优先，CDP）
          └── 内置 Chromium（备用，CDP）
```

Studio 是面向用户的唯一管理界面。Hermes Agent 不单独注册飞牛桌面入口。

## 5. FPK 目录设计

### 5.1 源码仓库

```text
HermesStudio-fnOS/
├── .github/workflows/
│   ├── build-fpk.yml
│   └── check-upstream-release.yml
├── fpk/
│   ├── app/
│   │   ├── launcher/
│   │   ├── hermes-agent/
│   │   ├── hermes-studio/
│   │   ├── runtime/
│   │   │   ├── python/
│   │   │   ├── node/
│   │   │   ├── chromium/
│   │   │   └── tools/
│   │   └── ui/
│   ├── cmd/
│   │   ├── main
│   │   ├── install_init
│   │   ├── install_callback
│   │   ├── upgrade_init
│   │   ├── upgrade_callback
│   │   ├── uninstall_init
│   │   ├── uninstall_callback
│   │   ├── config_init
│   │   └── config_callback
│   ├── config/
│   │   ├── privilege
│   │   └── resource
│   ├── wizard/
│   │   ├── install
│   │   ├── config
│   │   └── uninstall
│   ├── manifest
│   ├── ICON.PNG
│   └── ICON_256.PNG
├── patches/
│   ├── hermes-agent/
│   └── hermes-studio/
├── scripts/
│   ├── fetch-upstream.sh
│   ├── build-agent.sh
│   ├── build-studio.sh
│   ├── bundle-runtime.sh
│   ├── verify-runtime.sh
│   └── build-fpk.sh
├── versions.lock
└── README.md
```

上游完整源码不直接长期复制进仓库。构建时根据 `versions.lock` 下载对应正式 Release，应用补丁后生成 FPK 内容。

### 5.2 安装后目录

| 类型 | fnOS 路径/变量 | 用途 |
| --- | --- | --- |
| 程序文件 | `TRIM_APPDEST` | Studio、Agent、Python、Node、Chromium，只读运行文件 |
| 配置 | `TRIM_PKGETC` | FPK 启动配置、端口、工作目录设置 |
| 持久数据 | `TRIM_PKGVAR` | Hermes Home、Studio 数据库、Skills、会话、日志、浏览器 Profile |
| 临时数据 | `TRIM_PKGTMP` | Unix Socket、临时文件、运行时缓存 |
| 应用 Home | `TRIM_PKGHOME` | 包用户 Home |
| 用户文件 | `TRIM_DATA_ACCESSIBLE_PATHS` | 用户在飞牛授权的 NAS 目录 |

严禁在脚本中写死 `/vol1`、`/vol2` 或 `/var/apps/HermesStudio`，必须优先使用系统环境变量。

### 5.3 持久数据布局

```text
TRIM_PKGVAR/
├── hermes/                 # HERMES_HOME
│   ├── profiles/
│   ├── skills/
│   ├── memory/
│   ├── auth.json
│   ├── config.yaml
│   └── .env
├── studio/                 # HERMES_WEB_UI_HOME
│   ├── database/
│   ├── uploads/
│   ├── auth/
│   └── settings/
├── browser/
│   ├── profile/
│   └── downloads/
├── logs/
│   ├── app.log
│   ├── studio.log
│   ├── agent.log
│   ├── gateway.log
│   └── browser.log
├── run/
│   └── app.pid
└── backups/
```

## 6. Manifest 与飞牛集成

建议 `manifest`：

```ini
appname=HermesStudio
version=0.1.0
display_name=Hermes Studio
desc=Hermes Agent 的飞牛原生 Web 管理与自动化平台
source=thirdparty
platform=x86
maintainer=Personal Build
os_min_version=1.2.0401
desktop_uidir=ui
desktop_applaunchname=HermesStudio.main
service_port=8648
checkport=true
ctl_stop=true
disable_authorization_path=false
```

说明：

- 默认 WebUI 端口为 `8648`，安装向导允许修改。
- 使用普通端口入口和 Studio 自带登录验证，适合家庭局域网。
- `disable_authorization_path=false`，允许在飞牛应用设置中授权目录。
- 不声明 Python、Node 或 Docker 依赖，因为全部运行时均内置。

桌面入口 `app/ui/config` 指向用户设置的 WebUI 端口，入口类型为 `iframe`。如果 iframe 中存在 OAuth 或下载兼容问题，同时提供“在浏览器中打开”入口。

## 7. 运行时与离线依赖

### 7.1 Python

- 固定使用 Python 3.11 x86_64，满足 Hermes Agent `>=3.11,<3.14` 要求，并获得更完整的二进制 Wheel 兼容性。
- 使用独立、可迁移的 Python 运行时，安装到 `app/runtime/python`。
- 根据 Hermes Agent 正式 Release 的锁文件安装全部当前功能所需依赖。
- 不包含已明确排除的语音模型及仅服务于 Ekko/Coding Agent 的依赖。
- 内置 `uv`，仅用于运行时管理和诊断；正常启动不得联网修改环境。

### 7.2 Node.js

- 固定使用满足 Studio 要求的 x86_64 Node.js 版本，优先 Node.js 24 LTS。
- 生产构建产物和生产依赖全部放入 FPK。
- `node-pty`、`sharp` 等原生模块必须在与 fnOS glibc 兼容的构建环境中编译并验证。
- 不在 NAS 上执行 `npm install`。

### 7.3 Chromium 与工具

FPK 内置：

- Chromium x86_64；
- 与 Chromium 版本匹配的自动化组件；
- `ripgrep`、`ffmpeg`、Git 和应用实际调用的基础工具；
- 必要字体、证书和共享库。

安装前和构建后都要检查 ELF 架构、动态库依赖和 glibc 最低版本，避免在 GitHub Actions 中构建成功但在 fnOS 中无法运行。

## 8. Studio 与 Agent 集成

启动 Studio 时设置：

```text
HERMES_HOME=$TRIM_PKGVAR/hermes
HERMES_WEB_UI_HOME=$TRIM_PKGVAR/studio
HERMES_AGENT_ROOT=$TRIM_APPDEST/hermes-agent
HERMES_BIN=$TRIM_APPDEST/runtime/python/bin/hermes
HERMES_AGENT_BRIDGE_PYTHON=$TRIM_APPDEST/runtime/python/bin/python3
WORKSPACE_BASE=<用户授权的默认工作目录>
PORT=<安装向导端口，默认 8648>
BIND_HOST=0.0.0.0
CORS_ORIGINS=<同源>
```

集成要求：

- Studio 不再自动探测系统 Python、Node、Hermes CLI 或用户 Home。
- 所有路径明确指向 FPK 内置运行时和 `TRIM_PKGVAR`。
- Studio 负责启动并管理 Hermes Agent Bridge。
- Studio 启动时自动检查 Hermes Gateway，并按当前 Profile 启动消息网关。
- Agent Bridge、内部代理和浏览器调试端口仅绑定 `127.0.0.1` 或 Unix Socket。
- Hermes Agent 与 Studio 共享同一个 `HERMES_HOME` 数据源，避免配置重复和会话割裂。
- 隐藏或禁用 Ekko、Claude Code、Codex、Pi 和语音相关菜单、API 及后台初始化。

## 9. 浏览器方案

### 9.1 优先连接飞牛 Chrome

增加 Browser Adapter，启动时按以下顺序探测：

1. 用户在 Studio 设置中填写的 Chrome DevTools 地址。
2. 飞牛应用中心 Chrome 已知的本机 CDP 地址。
3. 对本机候选端口请求 `/json/version`，验证是否为可用 CDP 实例。

只有明确获得 CDP WebSocket 地址后才能连接。不得通过扫描整个局域网寻找浏览器。

### 9.2 内置 Chromium 备用

无法连接现有 Chrome 时，由 FPK 启动内置 Chromium：

```text
--headless=new
--remote-debugging-address=127.0.0.1
--remote-debugging-port=18792
--user-data-dir=$TRIM_PKGVAR/browser/profile
--download-default-directory=$TRIM_PKGVAR/browser/downloads
--no-first-run
--disable-dev-shm-usage
```

Chromium 以应用包用户运行，不长期使用 root。只有实际内核限制导致沙箱无法启动时，才允许受控启用兼容参数，并在日志和健康检查中明确提示。

### 9.3 功能边界

- 第一版提供“Agent 能控制浏览器”，不要求复刻 Electron 桌面端的原生多标签窗口。
- Studio WebUI 中应显示浏览器连接状态、当前使用的浏览器来源、调试地址、最近错误和重新连接按钮。
- 截图、页面结构、导航和下载通过 Hermes Agent/浏览器工具返回到 Studio。

## 10. 消息平台

保留上游所有消息平台配置页面和 Gateway 能力。第一版必须完成以下端到端验收：

### 10.1 个人微信

- Studio 显示登录二维码。
- 扫码完成后保存凭证到 `TRIM_PKGVAR/hermes`。
- NAS 重启、应用重启和 Studio 页面关闭后保持登录；上游平台强制失效时重新扫码。
- 页面显示登录状态、最后收信时间、错误原因和重新登录按钮。

个人微信接入依赖上游实现和微信服务策略，无法保证凭证永久有效。应用只能保证凭证正确持久化和失效后可重新登录。

### 10.2 QQ 开放平台

- 支持填写 App ID、Client Secret/Token 等上游所需字段。
- 凭证仅保存于服务器端，前端只返回脱敏状态。
- 支持允许用户/群、提及规则和启停控制。

### 10.3 Telegram

- 支持 Bot Token、允许用户、群聊和提及规则。
- 支持通过 Telegram 发起会话、停止任务并接收定时任务结果。

### 10.4 其他平台

- 保留上游配置入口与运行代码。
- 至少完成配置保存、Gateway 启动和错误提示的冒烟测试。
- 需要第三方回调、域名或公网入站的平台不属于“仅局域网即可完成”的能力，页面必须清楚提示其额外条件。

## 11. 文件、终端与权限

### 11.1 运行用户

`config/privilege` 使用专用包用户：

```json
{
  "defaults": {
    "run-as": "package"
  },
  "username": "hermesstudio",
  "groupname": "hermesstudio"
}
```

所有长期进程均以该用户运行，不以 root 运行 Studio、Agent、Gateway 或 Chromium。

### 11.2 授权目录

- 首次打开应用时必须完成默认工作目录授权，否则禁止执行文件和终端任务。
- 默认工作目录从 `TRIM_DATA_ACCESSIBLE_PATHS` 中选择。
- Studio 后端每次文件操作都要解析真实路径，并确认目标位于当前授权目录列表内。
- 拒绝 `..`、符号链接逃逸、挂载点穿越和未授权绝对路径。
- 新增授权目录后刷新运行配置，不要求重装应用。

### 11.3 命令审批

- 使用 Hermes 原生命令审批能力。
- 删除、覆盖、权限修改、磁盘操作、系统服务操作、软件安装、提权和访问授权目录外路径必须确认。
- 确认操作应在 Studio 中展示完整命令、工作目录、风险类型和发起任务。
- 禁止 Agent 绕过审批规则修改审批配置。

## 12. 首次使用流程

1. 从飞牛应用中心手动安装 FPK。
2. 安装向导设置 WebUI 端口，默认 `8648`。
3. 应用启动后打开 Hermes Studio。
4. 首次进入时创建管理员密码，不允许继续使用上游默认 `admin/123456`。
5. 选择并授权默认工作目录。
6. 添加模型 Provider/API Key，并执行模型连通测试。
7. 执行 Agent 对话测试。
8. 执行浏览器测试；优先连接飞牛 Chrome，失败时启动内置 Chromium。
9. 按需配置微信、QQ、Telegram、MCP 和定时任务。

WebUI 只面向家庭局域网，但认证不能关闭。

## 13. 生命周期脚本

### 13.1 安装前 `install_init`

- 检查系统架构为 x86_64。
- 检查 fnOS 版本满足最低要求。
- 检查安装空间和数据空间。
- 检查 WebUI 端口是否占用。
- 检查 FPK 内关键运行文件和校验和。
- 失败时写入 `TRIM_TEMP_LOGFILE`。

### 13.2 安装后 `install_callback`

- 创建 `TRIM_PKGVAR` 持久目录。
- 设置配置和密钥目录权限为 `0700`，密钥文件为 `0600`。
- 写入默认启动配置。
- 初始化 Studio 数据库和 Hermes Profile。
- 不执行任何联网下载。

### 13.3 启停 `cmd/main`

`start`：

- 清理失效 PID 和 Unix Socket。
- 载入内置 Python、Node、工具和证书路径。
- 校验默认工作目录仍在授权列表中。
- 启动 Studio；由 Studio 启动 Agent Bridge 和 Gateway。
- 启动或连接浏览器 Adapter。
- 等待健康检查成功后返回。

`stop`：

- 停止接收新任务。
- 停止 Studio 管理的 Gateway 和 Agent Bridge。
- 给正在执行的任务有限时间保存状态。
- 先发送 TERM，超时后再结束残留进程。
- 清理 PID 和临时 Socket，不删除持久数据。

`status`：

- Studio、Agent Bridge、Gateway 和健康接口均正常时返回 `0`。
- 未运行或核心组件不可用时返回 `3`。

### 13.4 升级

`upgrade_init`：

- 停止应用。
- 记录当前 Agent、Studio、数据结构版本。
- 备份关键配置和数据库元数据到 `TRIM_PKGVAR/backups`。

`upgrade_callback`：

- 执行上游要求的数据迁移。
- 保留 `TRIM_PKGETC` 和 `TRIM_PKGVAR`。
- 验证运行时、数据库和配置后再启动新版。
- 迁移失败时输出明确错误，不删除旧备份。

### 13.5 卸载

卸载向导提供：

- 保留配置与数据；
- 删除应用配置、会话、Skills、记忆、消息凭证和浏览器 Profile。

默认选择“保留数据”。

## 14. 安全要求

- WebUI 绑定 `0.0.0.0:8648`，只按家庭局域网场景设计。
- Agent Bridge、CDP、内部代理、数据库和调试接口只绑定本机。
- Studio 登录验证强制开启。
- 首次启动强制修改管理员密码。
- CORS 默认同源，不使用 `*`。
- API Key、机器人 Token、Cookie 和 OAuth 凭证不返回明文给浏览器。
- 日志对 API Key、Token、Cookie、Authorization Header 和个人信息脱敏。
- 文件接口实施路径规范化和授权目录校验。
- 危险命令强制审批。
- 不提供 root Shell，不让 Agent 管理 fnOS 系统应用和系统分区。
- 应用内禁用 `hermes update`、`npm update` 和 `pip install` 等自更新入口，避免破坏 FPK 可重复性。

## 15. 日志与健康检查

Studio 中增加“飞牛运行状态”页面，展示：

- Studio、Agent Bridge、Gateway、Chromium 运行状态；
- Hermes Agent 和 Hermes Studio 上游版本；
- 当前 FPK 版本；
- 当前工作目录与授权状态；
- 当前浏览器来源；
- 消息平台连接状态；
- 磁盘空间和日志大小；
- 最近启动错误；
- 下载诊断包按钮。

日志按大小轮转，默认单文件 20 MB、保留 5 份。诊断包必须脱敏，不包含密钥、完整 Cookie 和消息正文。

## 16. 自动构建与发布

### 16.1 版本锁定

`versions.lock` 至少记录：

```yaml
hermes_agent:
  version: <正式 Release>
  tag: <tag>
  commit: <完整 commit SHA>
hermes_studio:
  version: <正式 Release>
  tag: <tag>
  commit: <完整 commit SHA>
python: 3.11.x
node: 24.x
chromium: <固定版本>
```

禁止只使用 `latest` 构建，以免同一版本产生不可复现的内容。

### 16.2 Release 检查

- GitHub Actions 每 24 小时检查两个上游的最新正式 Release。
- 忽略 prerelease、nightly 和 main 分支提交。
- 任一上游出现新正式版后创建兼容性构建。
- 只有自动测试全部通过时才发布 FPK Release。
- 如果新版本不兼容，保留上一组可用版本并在构建日志中标记阻塞原因。

### 16.3 构建步骤

1. 下载并校验固定版本上游源码。
2. 应用 fnOS 补丁。
3. 构建 Hermes Agent Python 运行时。
4. 构建 Hermes Studio 前后端及生产依赖。
5. 打包 Node.js、Python、Chromium 和工具。
6. 删除语音、Coding Agent、Electron 桌面端和开发测试产物。
7. 执行 ELF、动态库、架构和依赖完整性检查。
8. 生成 SBOM、版本清单和 SHA256。
9. 使用当前稳定版 `fnpack` 构建 FPK。
10. 发布 FPK、SHA256、版本说明和上游版本组合。

## 17. 验收标准

### 17.1 安装与运行

- 在未安装 Docker、Python、Node、Chromium 开发依赖的 x86_64 fnOS 1.2 设备上安装成功。
- 安装阶段断开互联网仍能完成安装和启动。
- 应用中心可正确启动、停止和显示状态。
- NAS 重启后应用自动恢复运行。
- 端口冲突时给出明确错误。

### 17.2 Studio 与 Agent

- Studio 中配置模型后可以发起 Hermes Agent 对话。
- 流式输出、工具调用、文件产物和会话恢复正常。
- Skills、记忆、MCP、定时任务和工作流可新增、修改、运行。
- 关闭网页后，正在运行的后台任务和消息网关不停止。

### 17.3 数据持久化

- 应用停止/启动、NAS 重启后配置和会话仍存在。
- 覆盖升级后模型配置、Skills、记忆、任务、工作流和机器人凭证仍存在。
- 升级不删除用户工作目录中的文件。

### 17.4 消息平台

- 个人微信完成扫码、收消息、回复和重启恢复测试。
- QQ 开放平台完成私聊/群聊授权范围内的收发测试。
- Telegram 完成收发、停止任务和定时结果投递测试。
- 其他上游平台完成配置保存和 Gateway 冒烟测试。

### 17.5 文件与终端

- 文件管理只能访问授权目录。
- 未授权目录、符号链接逃逸和 `..` 穿越请求全部拒绝。
- 普通命令可执行。
- 危险命令必须显示确认，拒绝后不得执行。

### 17.6 浏览器

- CDP 可用时连接飞牛应用中心 Chrome。
- 连接失败时自动启动内置 Chromium。
- Agent 能完成打开网页、读取页面、点击、输入、截图和下载。
- 浏览器 Profile 和登录状态在应用重启后保留。

## 18. 主要风险与处理

| 风险 | 处理方式 |
| --- | --- |
| 飞牛 Chrome 未开放 CDP | 内置 Chromium 自动接管 |
| Studio 桌面浏览器依赖 Electron | 第一版采用 Agent 控制的 CDP 浏览器，不复刻 Electron 窗口 |
| 微信个人号协议变化或凭证失效 | 保留上游实现、状态检测和重新扫码流程，不承诺永久在线 |
| Python/Node 原生依赖与 fnOS glibc 不兼容 | 使用低版本 glibc 基线构建，并在真实 fnOS x86_64 设备验收 |
| FPK 体积较大 | 需求明确以完整可用为优先，不设置体积上限 |
| 两个上游发布节奏不同 | 通过 `versions.lock` 固定已验证的版本组合 |
| 上游更新破坏补丁 | 自动构建失败时不发布，保留最后可用版本 |
| 消息平台需要公网回调 | 页面明确提示外部条件；局域网模式不虚假宣称可用 |
| Agent 命令影响 NAS 数据 | 包用户、授权目录限制、路径校验和危险命令审批 |

## 19. 开发阶段

### 阶段一：运行环境验证

- 收集真实 fnOS 设备的 glibc、内核、CPU 指令集和共享库信息。
- 验证内置 Python、Node.js、`node-pty`、`sharp` 和 Chromium。
- 验证飞牛应用中心 Chrome 是否提供 CDP。

### 阶段二：最小原生 FPK

- 打包 Hermes Agent、Hermes Studio 和完整运行时。
- 实现安装、启停、状态、日志和持久化。
- 完成 Studio 与 Agent Bridge 的本地连接。

### 阶段三：飞牛适配

- 实现安装向导、桌面入口、端口配置和授权目录。
- 实现路径安全、包用户权限和健康状态页面。
- 禁用不在范围内的语音及其他 Agent 模块。

### 阶段四：浏览器与消息平台

- 实现飞牛 Chrome CDP 探测和内置 Chromium 回退。
- 完成微信、QQ、Telegram 端到端测试。
- 对其他上游消息平台执行冒烟测试。

### 阶段五：构建与升级

- 建立正式 Release 检查、版本锁定和 GitHub Actions 构建。
- 完成覆盖升级、数据迁移、失败回退和诊断包。
- 在真实 fnOS 1.2 x86_64 设备完成最终验收。

## 20. 开发完成定义

只有同时满足以下条件，第一版才算完成：

- 单个 FPK 可在 fnOS 1.2 x86_64 上离线安装。
- 不依赖 Docker，不在安装或启动时下载运行依赖。
- Hermes Studio 能稳定管理和使用内置 Hermes Agent。
- Studio、Agent Bridge、Gateway、Skills、记忆、MCP、Cron、Workflow、文件、终端和浏览器均可用。
- 个人微信、QQ 开放平台和 Telegram 完成真实收发验收。
- 只能访问飞牛授权目录，危险命令必须确认。
- 关闭网页和重启 NAS 后后台服务可恢复。
- 覆盖升级保留全部持久数据。
- 自动构建只跟踪两个上游的正式 Release，并且不发布未通过测试的版本组合。

## 21. 参考资料

- 飞牛应用开发文档：https://github.com/ckcoding/fnnas-docs
- Hermes Agent：https://github.com/NousResearch/hermes-agent
- Hermes Studio：https://github.com/EKKOLearnAI/hermes-studio

