# Hermes Agent + Hermes Studio for fnOS

这是 `fnOS 1.2 x86_64` 的双 FPK 工程：

- `HermesAgent.fpk`：内置 Python、Hermes Agent、全部运行依赖、消息网关、定时任务和备用 Chromium。
- `HermesStudio.fpk`：内置 Node 和上游 Hermes Studio WebUI，通过官方 CLI/Bridge/Gateway 接口连接 Agent。

两个 FPK 不修改 Hermes 上游页面和业务功能。Agent 是长期运行的后台服务，Studio 是可独立启停的管理界面；停止 Studio 或关闭浏览器不会停止 Agent 的机器人和定时任务。

## 构建

构建机必须是 Linux `x86_64`，且能访问 GitHub、Node.js、Python standalone 和 Chrome for Testing 下载地址。

```bash
export FPK_VERSION=0.1.6
./scripts/build-release.sh
```

所有 Python、Node、uv、Chromium 和 Hermes 依赖都在 Actions 构建阶段进入 FPK，安装到 fnOS 后不下载依赖。

## 安装顺序

1. 安装 `HermesAgent-0.1.6-fnOS-x86_64.fpk`。
2. 在 Agent 配置中选择一个 fnOS 授权目录，并配置模型/API 和消息平台。
3. 安装 `HermesStudio-0.1.6-fnOS-x86_64.fpk`。
4. 从 fnOS 应用中心打开 Hermes Studio。

Studio 依赖 Agent。若 Agent 没有安装、没有启动或共享目录权限不正确，Studio 会显示明确的修复提示。

## 日志与故障排查

两个应用都会保留独立日志，并在应用中心入口中提供日志页面：

- Hermes Agent 日志：`http://NAS地址:8643/`
- Hermes Studio 日志：`http://NAS地址:8649/`

日志页面可以查看最近日志并导出日志包。Agent 重点查看 `install.log`、`app.log`、`gateway.log`、`browser.log`；Studio 重点查看 `install.log`、`app.log`、`studio.log`。日志目录位于各应用的 `TRIM_PKGVAR/logs/`。

Hermes Agent 使用“小安装层”封装：fnOS 直接解压的 `app.tgz` 只包含界面、日志服务、静态 BusyBox 和单个 `runtime-payload.tgz`，避免在应用中心一次解压数万个 Python/Chromium 文件。安装/升级回调再使用包内 BusyBox 在 NAS 本地离线展开运行时；全程不下载依赖。构建流程会验证外层包、内部 `app.tgz`、checksum、路径、重复成员，以及实际展开 Agent 运行时的结果；日志保存到 `dist/fpk-payload-check.log` 并随 Release 发布。

## 版本与 Release

- 包版本从 `0.1.0` 开始，当前安装兼容性修复版本为 `0.1.6`，由 `FPK_VERSION` 控制。
- 上游只读取 Hermes Agent 和 Hermes Studio 的正式 Release，不使用 prerelease、branch 或未发布 commit。
- `.github/workflows/build-release.yml` 负责构建双 FPK，并在构建通过后创建或更新对应 Release。
- `.github/workflows/check-upstream-release.yml` 每天检查正式 Release；发现新版本时触发构建流程。

## 限制

目标为个人家庭局域网使用，仅支持 `x86_64`。个人微信扫码和 QQ 开放平台能力必须以对应 Hermes Agent 正式 Release 原生支持的适配器为准；打包层不会伪造不存在的上游功能。

详细方案见 `docs/HermesAgent-HermesStudio-fnOS-双FPK开发文档.md`，日志排查见 `docs/日志与故障排查.md`。
