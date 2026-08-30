# Product

<!-- impeccable:product-schema 1 -->

## Platform

Omarchy / Quickshell 原生桌面 QML

## Users

主要用户是使用 Omarchy，并希望随时查看 CodexBar 用量信息的用户。他们需要从桌面右上角托盘快速打开状态面板，尽可能详细地查看各提供商及 Agent 的用量。

## Product Purpose

CodexBar 插件将 `codexbar serve` 提供的状态与用量能力映射到 Omarchy 的 QML 界面，并在独立 Radar 标签中展示 Codex Radar 的场景化模型推荐。产品成功意味着用户无需切换到独立网页或终端，只需点击右上角托盘即可快速查看详细用量并比较推荐模型的 IQ、耗时和费用。

## Positioning

插件不创造或复制 CodexBar 的业务逻辑；它的独特价值是把 CodexBar 已有能力原生地放进 Omarchy 的日常桌面工作流中，并缩短为一次托盘点击。

## Operating Context

- 运行于 Omarchy Linux 桌面环境，通过右上角托盘入口打开。
- `codexbar serve` 是服务启动、状态、用量数据和操作能力的唯一事实来源。
- Codex Radar 是 Radar 标签的推荐与效率指标事实来源；外部请求与 CodexBar 本机服务生命周期保持隔离。
- QML 层负责服务生命周期协调、连接状态映射、界面展示和用户交互。
- 用户主要在日常使用 Agent 的过程中快速检查用量，而不是进入独立的管理流程。

## Capabilities and Constraints

- 展示 `codexbar serve` 提供的尽可能详细的提供商及 Agent 用量信息。
- 在 Overview 的 30 天价格数字下方用同一行紧凑展示 Daily development 与 Hard problems 的首选模型及 IQ，并固定标签顺序为 Overview、Codex、Radar、其他提供商（无 Codex 时 Radar 紧跟 Overview）。Radar 按官网当前规则展示四类英文模型推荐及每类两条模型/档位、IQ、平均耗时和费用；只有四组均完整时才替换缓存，顶部标签轨道与底部操作区在内容滚动时保持固定。
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
- Codex Radar 当前页面使用 `/api/radar-insights` 与 `/api/intelligence-efficiency-metrics` 合并生成站长推荐；其公开摘要声明完整 JSON API 与二次开发需要授权。
- 当前仓库已有可运行的 QML 托盘面板与原生捕获证据；没有用户研究、案例或性能数据，后续工作不得虚构这些证据。

## Product Principles

1. CodexBar 服务是用量与成本的唯一事实来源；Codex Radar 是模型推荐的外部事实来源，二者由独立适配器可靠映射。
2. 一次点击即可看见高密度、可扫描的详细用量。
3. 服务状态与错误必须清楚、可恢复，不能让用户猜测连接情况。
4. 融入 Omarchy 的桌面习惯，不创造额外的管理流程。
