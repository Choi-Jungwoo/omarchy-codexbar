---
name: CodexBar
description: Omarchy 原生的 30 天用量与提供商剩余额度仪表。
---

# Design System: CodexBar

## Overview

**Creative North Star: "Usage Ledger"**

CodexBar 是 Omarchy 桌面中的紧凑原生仪表，而不是独立应用或网页仪表盘。它沿用宿主栏与弹层的视觉语言，把最近 30 天用量与支出、所有可用提供商的剩余额度，以及 Codex 的详细遥测压进一次右上角托盘交互中。

视觉世界保持平面、精确、克制：运行时主题提供颜色、字体、间距、圆角与控件状态；细分隔线建立层级；紧凑等宽排版承担高密度遥测。强调色统一承载选择、交互和正常剩余额度，紧急色只表达服务失败或真正的额度风险。

**Key Characteristics:**

- Omarchy 原生栏控件与弹层，不另造一条状态栏。
- 默认先读 30 天总览，再扫描提供商剩余额度；Codex 固定在列表首位以承载唯一的悬停详情。
- 平面表面、细分隔线、紧凑等宽遥测和克制状态色。
- 服务状态、用量、重置时间、成本和恢复动作都保持可扫描。

## Colors

颜色不固化为项目私有色板；它们在运行时从当前 Omarchy 主题继承，因此浅色、深色和用户主题都保持一致。

### Primary

- **宿主强调色**（`Color.accent`）：用于已选分段、交互焦点、宿主按钮状态和正常的剩余额度填充；已选分段使用低强度强调填充（22% alpha）。
- **宿主紧急色**（`bar.urgent`，回退到 `Color.urgent`）：服务错误或窗口剩余额度低于等于 10% 时使用。错误提示表面以 10% alpha 着色、边框以 35% alpha 着色。

### Neutral

- **宿主前景色**（`bar.foreground`，回退到 `Color.popups.text`）：主文本、正常状态与按钮文字。
- **可读弱化色**（前景色 66% alpha）：重置时间、剩余额度、来源、更新时间和辅助说明。它由本面板前景色派生，不直接使用可能过淡的全局装饰性 muted token。
- **选择轨道色**（`Style.selectedFillFor(foreground, accent)`）：剩余额度条未填充轨道，随当前主题计算。预计剩余刻度使用弹层背景色切开填充与轨道，在任何主题下都保持可见。
- **局部细线色**（前景色 18%–32% alpha）：提示框边框、分段轨道与分段间线；列表分隔线继续使用宿主 `PanelSeparator` 的主题处理。

**The Remaining-Quota Rule.** 色条长度始终表示剩余而不是已用；正常余量使用宿主强调色，只有剩余低于等于 10% 或服务失败才使用紧急色。

**The Host Owns the Palette Rule.** 不在插件中复制 Tokyo Night 或任何固定主题值；始终通过 Omarchy token 与宿主栏属性取色。

## Typography

**Display Font:** 无独立展示字体
**Body Font:** 当前 Omarchy 栏字体（`bar.fontFamily`，回退到 `Style.font.family`）
**Label/Mono Font:** 与宿主栏字体相同；当前视觉以紧凑等宽字形呈现遥测

**Character:** 字体服务于快速扫描而非品牌表演。数字、百分比、重置时间和成本保持紧密对齐；层级来自宿主的 `Style.font` 尺度、字重和大小写，而不是额外字体家族。

### Hierarchy

- **Summary**（`Style.font.title × 1.35`，bold）：Overview 最近 30 天总成本；没有成本但有 token 时显示总 token。
- **Title**（`Style.font.title`，bold）：当前提供商标题。
- **Body**（`Style.font.body`）：提供商详情中的窗口标题与积分值。
- **Body Small**（`Style.font.bodySmall`）：分段标签、空状态、成本行与刷新按钮。
- **Caption**（`Style.font.caption`）：状态、节标题、窗口元数据、剩余额度、重置时间与成本辅助行；状态和关键标签可加粗。

**The Telemetry Hierarchy Rule.** Overview 最大、最重的数字是最近 30 天总成本，成本缺失时才由总 token 替代；提供商名、剩余比例、预计剩余刻度、恢复时间和成本细目依次退后。

## Layout

CodexBar 以现有 Omarchy 右侧区域 `BarIconButton` 为入口；它不是一条独立 bar。点击入口打开锚定于该按钮的 `KeyboardPanel`。弹层的原生目标几何为 380×720 逻辑像素（`Style.space(380)` × `Style.space(720)`），小屏由宿主可用高度自动封顶；主内容区垂直滚动，页脚固定在面板底部。

首屏顺序固定为：连续动态分段轨道、细分隔线、30 天标题与服务状态、可选状态/错误提示、30 天总支出及覆盖摘要、提供商列表；更新时间、当前成本、刷新与退出面板按钮组成始终贴底的独立页脚。主要纵向节奏由 `Style.space(12)` 建立，列表与页脚内部使用更紧凑的 7–10 个 style-space 单位。

分段轨道始终是一整块连续边框表面：Overview 固定在首位，随后只出现服务成功返回的真实提供商。每段最小宽度为 `Style.space(84)`，轨道高度为 `Style.space(34)`；提供商过多时轨道水平滚动，不压缩到不可读。

Overview 将 Codex 固定在首位，方便发现唯一的悬停展开入口；其余提供商保持由最紧张窗口决定的服务模型顺序。每行紧凑展示全部真实配额窗口的剩余比例、重置时间和服务提供时的动态 pace 刻度。Codex 在悬停或键盘游标落入时内联增加账号、套餐、pace 摘要、reset credits、当前成本、30 天成本和最多 7 个日历史柱；其他提供商不会因悬停膨胀。进入独立提供商页后仍展示该提供商的完整数据。

**The Overview-First Rule.** 每次打开都进入 Overview；提供商标签和列表只来自服务成功记录，不为未配置的提供商保留空位置。

## Elevation & Depth

系统保持平面，不使用渐变、玻璃、模糊、发光或大阴影。层级由宿主弹层表面、`BorderSurface` 的细边框、`PanelSeparator` 和低 alpha 状态填充建立；悬停和选择只改变局部色调，不产生抬升。

**The Flat Popup Rule.** 弹层内部不堆叠浮动卡片；Provider Ledger 行共享同一表面语境，由留白、游标状态和细分隔线区分。

## Shapes

所有容器和控件复用 `Style.cornerRadius`，不建立 CodexBar 专属圆角尺度。分段的内层选中面在宿主圆角上扣除 `Style.space(2)`；进度条两端使用半高圆角，状态指示器为圆点。整体轮廓偏克制，避免大胶囊、大卡片和高装饰性形状。

## Components

### Bar Entry

- 使用宿主已有右侧区域的 `BarIconButton`，图标与 Tooltip 承担唯一入口；不得渲染第二条 bar 或独立悬浮入口。
- 普通点击切换弹层；中键直接刷新。
- 服务失败或任一首要约束达到 90% 时进入 active 状态；失败时 Tooltip 明确为 connection failed。

### KeyboardPanel

- 锚定 Bar Entry，继承宿主 bar、弹层尺寸计算、焦点管理和跨面板切换行为。
- 打开时总是回到 Overview、Provider Ledger 首行和滚动顶部，并立即请求刷新。
- 内容区使用止于边界的 `Flickable`；只在内容超过视口时显示滚动条。

### Provider Segment Track

- 一块连续 `BorderSurface` 承载 Overview 与所有真实提供商分段。
- 选中态为低强度强调填充与强调色文字；悬停或键盘游标为 9% 前景色填充；分段间用 1px 细线连接。
- 标签来源于规范化后的服务记录；空 provider id、错误记录和重复记录被过滤，未知但非空的真实 provider id 会被安全地人类化后展示。

### 30-Day Overview Summary

- Overview 默认先汇总所有活跃提供商可用的 `last30DaysCostUSD` 与 `last30DaysTokens`，并显示有 30 天数据的提供商数/活跃提供商总数。
- 有成本时以总成本为主数值，同时按可用性显示 token；只有 token 时以 token 为主数值。两者都缺失时显示明确的 unavailable 文案，不补示意值。

### Provider Ledger Row

- 每行显示提供商及服务实际返回的全部配额窗口；每个窗口给出剩余比例、重置时间、remaining meter，以及服务提供 `expectedUsedPercent` 时的预计剩余刻度。
- 配额条长度表示 `remainingPercent`。正常填充使用主题强调色；剩余低于等于 10% 时切换紧急色。
- 服务返回 `expectedUsedPercent` 时，将其换算为 `expectedRemainingPercent`，在条上画一个会随刷新移动的预计剩余刻度；没有 pace 数据则不画刻度，不使用固定分段。
- Codex 行在鼠标悬停或键盘游标落入时展开，鼠标离开后收起；其他提供商悬停只显示常规游标状态。点击或键盘激活仍进入该提供商详情。
- 配额宽度和 pace 刻度以 220ms `OutExpo` 动画响应新数据；分段色调以 100ms 过渡响应选择与悬停。

### Codex Inline Expansion

- 只有 provider id 为 `codex` 的行能够内联展开，且只由该行鼠标 hover 或键盘游标命中触发；面板打开本身不自动展开。
- 展开后显示打码后的账号/套餐、各窗口非空的 pace summary、reset credits、当前成本与 token、30 天成本与 token，以及最多最近 7 条日成本/日 token 柱。邮箱本地部分只保留 1–2 个开头字符，右侧 `30 DAYS` 节标题与其金额、token 统一右对齐。
- Reset credits 以 `availableCount` 显示可用次数；若后端只返回 credits 数组则以数组长度回退。到期文案取可用 credit 中最早的 `expiresAt`，没有可用到期时间时不显示该行。

### Provider Detail

- 展示该提供商返回的全部有效限制窗口，并对每个窗口显示剩余比例、已用比例、重置时间和可用的 pace 摘要与动态预计剩余刻度；无 pace summary 或 `expectedUsedPercent` 时分别省略文案或刻度。
- 积分、当前/今日或会话成本、token、最近 30 天成本仅在字段存在时出现；缺失字段使用破折号或省略整个可选区域，不伪造数据。

### Service and Recovery States

- `stopped`、`starting`、`ready`、`error` 与 refreshing 映射为明确文案和状态点。
- 错误且仍有缓存提供商时显示 “SHOWING LAST DATA”；没有缓存时显示 “CONNECTION FAILED”。错误提示保留可理解的原因与 Retry 动作。
- ready 但无有效提供商时显示 “NO ACTIVE PROVIDERS” 和可恢复空状态；刷新期间禁用按钮并展示旋转图标。

### Input Behavior

- 左右方向键循环切换 Overview/提供商；Overview 中上下键移动提供商游标，落到 Codex 时提供与悬停等价的展开状态；详情中上下键按 `Style.space(56)` 滚动。
- Enter/激活键在 Overview 打开当前提供商，在详情触发刷新；Escape 关闭；Tab/Shift+Tab 交给宿主切换面板。
- `R` 刷新，`O` 返回 Overview。鼠标支持分段点击、Provider Ledger 行悬停/点击、滚轮/拖动滚动、Retry、Refresh 与 Exit panel 按钮；Exit panel 只关闭弹层。

## Do's and Don'ts

### Do:

- **Do** 从 Omarchy 的 `Color`、`Style`、`Border` 和现成 Ui 组件继承视觉与交互。
- **Do** 默认显示 30 天 Overview，并只为服务成功记录生成提供商分段与列表项。
- **Do** 在 380×640 逻辑视口中优先保证 30 天摘要、剩余额度、重置时间、Codex 详情、更新时间和刷新可扫描。
- **Do** 对缺失字段、短暂断线和刷新失败采取防御性呈现，并保留最后一次可用数据。
- **Do** 同时维持完整的鼠标与键盘路径。

### Don't:

- **Don't** 新建独立 bar、provider-first 默认页或固定提供商标签。
- **Don't** 把色条解释为已用比例，或用固定等分线冒充预计剩余刻度。
- **Don't** 引入 macOS 玻璃、渐变、模糊、发光、大阴影或堆叠圆角卡片。
- **Don't** 为服务未返回的限制、成本、积分或提供商填充示意值。
- **Don't** 绕过宿主 token 硬编码当前主题的颜色、字体、间距或圆角。
