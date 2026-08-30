# Product

<!-- impeccable:product-schema 1 -->

## Platform

Omarchy / Quickshell 原生桌面 QML

## Users

主要用户是使用 Omarchy，并希望随时查看 CodexBar 用量信息的用户。他们需要从桌面右上角托盘快速打开状态面板，尽可能详细地查看各提供商及 Agent 的用量。

## Product Purpose

CodexBar 插件将 `codexbar serve` 提供的状态与用量能力映射到 Omarchy 的 QML 界面。产品成功意味着用户无需切换到独立网页或终端，只需点击右上角托盘即可快速查看详细用量。

## Positioning

插件不创造或复制 CodexBar 的业务逻辑；它的独特价值是把 CodexBar 已有能力原生地放进 Omarchy 的日常桌面工作流中，并缩短为一次托盘点击。

## Operating Context

- 运行于 Omarchy Linux 桌面环境，通过右上角托盘入口打开。
- `codexbar serve` 是服务启动、状态、用量数据和操作能力的唯一事实来源。
- QML 层负责服务生命周期协调、连接状态映射、界面展示和用户交互。
- 用户主要在日常使用 Agent 的过程中快速检查用量，而不是进入独立的管理流程。

## Capabilities and Constraints

- 展示 `codexbar serve` 提供的尽可能详细的提供商及 Agent 用量信息。
- 保持服务通信与视觉组件分离，并先将后端响应转换为稳定的 QML 模型。
- 明确处理 `stopped`、`starting`、`ready` 和 `error` 等服务状态。
- 服务与文件操作保持异步，不阻塞 QML 渲染路径。
- 同一用户会话只应有一个由插件负责的 `codexbar serve` 实例；插件只清理自己启动的进程。
- 端口、套接字和启动参数必须来自实际 CLI 帮助、配置或既有代码，不使用未经确认的硬编码值。
- 插件只是 `codexbar serve` 的界面映射，不在 QML 中复制其业务逻辑。

## Brand Commitments

- 产品名称沿用 CodexBar。
- 界面沿用 Omarchy 当前主题、间距和交互模式。

## Evidence on Hand

- `AGENTS.md` 记录了项目目标、QML 边界、服务生命周期要求与完成标准。
- 本机 `codexbar serve --help` 确认 CodexBar 0.56.0 提供健康检查、用量、成本和仪表盘快照等 HTTP 接口。
- 当前仓库尚无已实现的 QML 界面、视觉资产、用户研究、案例或性能数据；后续工作不得虚构这些证据。

## Product Principles

1. CodexBar 服务是唯一事实来源，插件只做可靠映射。
2. 一次点击即可看见高密度、可扫描的详细用量。
3. 服务状态与错误必须清楚、可恢复，不能让用户猜测连接情况。
4. 融入 Omarchy 的桌面习惯，不创造额外的管理流程。
