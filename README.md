# Hermes Agent + Hermes Studio for fnOS

这是 `fnOS 1.2 x86_64` 的双 FPK 工程：

- `HermesAgent.fpk`：内置 Python、Hermes Agent、全部运行依赖、消息网关、定时任务和备用 Chromium。
- `HermesStudio.fpk`：内置 Node 和上游 Hermes Studio WebUI，通过官方 CLI/Bridge/Gateway 接口连接 Agent。

两个 FPK 不修改 Hermes 上游页面和业务功能。Agent 是长期运行的后台服务，Studio 是可独立启停的管理界面；停止 Studio 或关闭浏览器不会停止 Agent 的机器人和定时任务。

## 构建

构建机必须是 Linux `x86_64`，且能访问 GitHub、Node.js、Python standalone、Chrome for Testing 和 fnOS `fnpack` 下载地址。

```bash
export FPK_VERSION=0.1.0
./scripts/build-release.sh
```

所有 Python、Node、uv、Chromium 和 Hermes 依赖都在 Actions 构建阶段进入 FPK，安装到 fnOS 后不下载依赖。

## 安装顺序

1. 安装 `HermesAgent-0.1.0-fnOS-x86_64.fpk`。
2. 在 Agent 配置中选择一个 fnOS 授权目录，并配置模型/API 和消息平台。
3. 安装 `HermesStudio-0.1.0-fnOS-x86_64.fpk`。
4. 从 fnOS 应用中心打开 Hermes Studio。

Studio 依赖 Agent。若 Agent 没有安装、没有启动或共享目录权限不正确，Studio 会显示明确的修复提示。

## 版本与 Release

- 包版本从 `0.1.0` 开始，由 `FPK_VERSION` 控制。
- 上游只读取 Hermes Agent 和 Hermes Studio 的正式 Release，不使用 prerelease、branch 或未发布 commit。
- `.github/workflows/build-release.yml` 负责构建双 FPK，并在构建通过后创建或更新对应 Release。
- `.github/workflows/check-upstream-release.yml` 每天检查正式 Release；发现新版本时触发构建流程。

## 限制

目标为个人家庭局域网使用，仅支持 `x86_64`。个人微信扫码和 QQ 开放平台能力必须以对应 Hermes Agent 正式 Release 原生支持的适配器为准；打包层不会伪造不存在的上游功能。

详细方案见 `docs/HermesAgent-HermesStudio-fnOS-双FPK开发文档.md`。

