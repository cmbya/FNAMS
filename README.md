# Hermes Studio for fnOS

这是面向 fnOS 1.2、x86_64 的单应用原生 FPK 工程。它把 Hermes Agent 运行时与 Hermes Studio WebUI 打进同一个应用，由 Studio 管理 Agent 网关、会话、Skills、记忆、MCP、任务和消息平台。

## 当前状态

仓库当前提供 FPK 目录结构、生命周期脚本、上游 Release 锁定和 GitHub Actions 构建入口。完整 FPK 需要在 Actions 中提供已审核的 Python/Chromium 离线运行时归档，并在真实 fnOS 设备上完成安装与联调。

## 本地构建

```bash
export PYTHON_STANDALONE_ARCHIVE_URL='https://...'
export CHROMIUM_ARCHIVE_URL='https://...'
./scripts/build-fpk.sh
```

构建脚本默认只下载锁定的正式 Release，并从上游 `uv.lock` 导出除语音相关 extras 外的完整功能依赖（含消息平台）。不会迁移 Docker 数据。所有运行时依赖进入 FPK，安装阶段不访问网络。

## 运行约束

- 目标架构：x86_64（fnOS manifest 使用 `platform=x86`）。
- WebUI：局域网访问，端口 8648。
- 数据：`$TRIM_PKGVAR`；配置：`$TRIM_PKGETC`；临时文件：`$TRIM_PKGTMP`。
- 工作目录：安装向导选择的授权目录，默认由用户在 fnOS 安装时配置。
- 仅保留 Hermes Agent；不集成 Claude Code、Codex、Pi 或语音功能。
- 优先使用 fnOS 应用中心 Chrome；不可用时使用 FPK 内置 Chromium。

## 目录

```text
fpk/       FPK 包内容
scripts/   上游获取、运行时打包和 FPK 构建脚本
versions.lock
```

开发约束与验收标准见 [HermesStudio-fnOS-开发文档.md](./HermesStudio-fnOS-开发文档.md)。
