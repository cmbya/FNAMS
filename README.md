# Hermes Agent + Hermes Studio for fnOS

这是 \`fnOS 1.2 x86_64\` 的双 FPK 工程：

- \`HermesAgent.fpk\`：内置 Python、Hermes Agent、全部运行依赖、消息网关、定时任务和备用 Chromium。
- \`HermesStudio.fpk\`：内置 Node 和上游 Hermes Studio WebUI，通过官方 CLI/Bridge/Gateway 接口连接 Agent。

两个 FPK 不修改 Hermes 上游页面和业务功能。Agent 是长期运行的后台服务，Studio 是可独立启停的管理界面；停止 Studio 或关闭浏览器不会停止 Agent 的机器人和定时任务。

## 构建

构建机必须是 Linux \`x86_64\`，且能访问 GitHub、Node.js、Python standalone 和 Chrome for Testing 下载地址。

推荐使用 GitHub Actions 的 \`Build selected Hermes fnOS FPK\`：

1. 选择 \`agent\`、\`studio\` 或 \`both\`。
2. 分别填写 \`agent_version\`、\`studio_version\`；留空时，系统读取对应项目已有的正式 Release 版本并自动递增。
3. 勾选 \`Resolve the newest formal upstream Releases\` 时，构建会锁定对应项目最新正式上游 Release。
4. 选择 \`both\` 时仍然生成两个独立 FPK、两个独立 Release（\`agent-vX.Y.Z\` 和 \`studio-vX.Y.Z\`），不会合并为一个版本。

版本号规则是每个项目独立递增：普通情况下 \`0.1.8 → 0.1.9\`；\`0.1.9\` 之后进入 \`0.2.0\`。手动输入的版本号优先于自动递增。

本地构建示例：

\`\`\`bash
BUILD_TARGET=agent AGENT_PACKAGE_VERSION=0.2.0 ./scripts/build-release.sh
BUILD_TARGET=studio STUDIO_PACKAGE_VERSION=0.1.4 ./scripts/build-release.sh
\`\`\`

所有 Python、Node、uv、Chromium 和 Hermes 依赖都在 Actions 构建阶段进入 FPK，安装到 fnOS 后不下载依赖。

## 安装顺序

1. 安装对应版本的 \`HermesAgent-X.Y.Z-fnOS-x86_64.fpk\`。
2. 在 Agent 的“应用设置 → 授权目录”中选择一个现有文件夹（例如 \`/vol2/1000/HermesWorkspace\`），然后保存。该目录不需要预分配容量，实际可用空间由所在存储空间的剩余容量或配额决定。
3. 安装对应版本的 \`HermesStudio-X.Y.Z-fnOS-x86_64.fpk\`。
4. 从 fnOS 应用中心打开 Hermes Studio。

Studio 依赖 Agent。若 Agent 没有安装、没有启动或共享目录权限不正确，Studio 会显示明确的修复提示。

## 日志与故障排查

两个应用都会保留独立日志，并在应用中心入口中提供日志页面：

- Hermes Agent 日志：\`http://NAS地址:8643/\`
- Hermes Agent 状态：\`http://NAS地址:8643/status\`
- Hermes Studio 日志：\`http://NAS地址:8649/\`

日志页面可以查看最近日志并导出日志包。Agent 重点查看 \`install.log\`、\`app.log\`、\`gateway.log\`、\`browser.log\`；Studio 重点查看 \`install.log\`、\`app.log\`、\`studio.log\`。日志目录位于各应用的 \`TRIM_PKGVAR/logs/\`。

Hermes Agent 使用“小安装层”封装：fnOS 直接解压的 \`app.tgz\` 只包含界面、日志服务、静态 BusyBox 和单个 \`runtime-payload.tgz\`，避免在应用中心一次解压数万个 Python/Chromium 文件。安装/升级回调再使用包内 BusyBox 在 NAS 本地离线展开运行时；全程不下载依赖。构建流程会验证外层包、内部 \`app.tgz\`、checksum、路径、重复成员，以及实际展开 Agent 运行时的结果；日志保存到 \`dist/fpk-payload-check.log\` 并随 Release 发布。

浏览器工具优先连接 fnOS 主机上的 Chrome CDP：先检测 \`127.0.0.1:16002\`，再检测 Docker/socat 转发地址 \`172.28.0.1:16003\`；两者均不可用时自动回退到 Agent FPK 内置的 Chromium。即使使用外部 Chrome，Agent FPK 仍会离线包含 \`agent-browser\` 控制程序和 Node.js，不会在 NAS 上临时下载 npm 包。

## 版本与 Release

- Agent 和 Studio 的包版本分别记录在 \`versions.lock\` 的 \`AGENT_PACKAGE_VERSION\` 与 \`STUDIO_PACKAGE_VERSION\`，互不绑定。
- 上游只读取 Hermes Agent 和 Hermes Studio 的正式 Release，不使用 prerelease、branch 或未发布 commit。
- \`.github/workflows/build-release.yml\` 支持手动选择单个项目或两个项目；空版本号按对应项目 Release 自动递增。
- \`.github/workflows/check-upstream-release.yml\` 每天北京时间 12:10（UTC 04:10）检查正式上游 Release。发现哪个项目更新，就只触发哪个项目的独立构建；两个项目都更新时，会触发两个独立构建。
- 自动构建通过并发锁串行更新 \`versions.lock\`，但产物、版本号和 Release 始终按 Agent/Studio 分开。

## 限制

目标为个人家庭局域网使用，仅支持 \`x86_64\`。个人微信扫码和 QQ 开放平台能力必须以对应 Hermes Agent 正式 Release 原生支持的适配器为准；打包层不会伪造不存在的上游功能。

详细方案见 \`docs/HermesAgent-HermesStudio-fnOS-双FPK开发文档.md\`，日志排查见 \`docs/日志与故障排查.md\`。
