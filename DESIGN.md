---
name: CodexBar
description: Omarchy 原生的约束优先提供商用量仪表。
---

# Design System: CodexBar

## Overview

**Creative North Star: "Constraint Queue"**

CodexBar 是 Omarchy 桌面中的紧凑原生仪表，而不是独立应用或网页仪表盘。它沿用宿主栏与弹层的视觉语言，把服务健康、最可能阻断下一次请求的配额，以及提供商详情压进一次右上角托盘交互中。

视觉世界保持平面、精确、克制：运行时主题提供颜色、字体、间距、圆角与控件状态；细分隔线建立层级；紧凑等宽排版承担高密度遥测。强调色只标识选择和交互，紧急色只表达服务失败或真正的额度风险。

**Key Characteristics:**

- Omarchy 原生栏控件与弹层，不另造一条状态栏。
- 以约束程度而非提供商身份组织默认视图。
- 平面表面、细分隔线、紧凑等宽遥测和克制状态色。
- 服务状态、用量、重置时间、成本和恢复动作都保持可扫描。

## Colors

颜色不固化为项目私有色板；它们在运行时从当前 Omarchy 主题继承，因此浅色、深色和用户主题都保持一致。

### Primary

- **宿主强调色**（`Color.accent`）：只用于已选分段、交互焦点和宿主按钮状态；已选分段使用低强度强调填充（22% alpha），不把它扩散到所有配额条。
- **宿主紧急色**（`bar.urgent`，回退到 `Color.urgent`）：服务错误或绑定窗口已用额度达到 90% 时使用。错误提示表面以 10% alpha 着色、边框以 35% alpha 着色。

### Neutral

- **宿主前景色**（`bar.foreground`，回退到 `Color.popups.text`）：主文本、正常状态、普通配额填充与按钮文字。
- **可读弱化色**（前景色 66% alpha）：重置时间、剩余额度、来源、更新时间和辅助说明。它由本面板前景色派生，不直接使用可能过淡的全局装饰性 muted token。
- **选择轨道色**（`Style.selectedFillFor(foreground, accent)`）：进度条未填充轨道，随当前主题计算。
- **局部细线色**（前景色 18%–32% alpha）：提示框边框、分段轨道与分段间线；列表分隔线继续使用宿主 `PanelSeparator` 的主题处理。

**The Risk-Only Urgency Rule.** 紧急色只在服务失败或用量达到 90% 的窗口上出现；正常、健康和品牌差异不各自发明颜色。

**The Host Owns the Palette Rule.** 不在插件中复制 Tokyo Night 或任何固定主题值；始终通过 Omarchy token 与宿主栏属性取色。

## Typography

**Display Font:** 无独立展示字体
**Body Font:** 当前 Omarchy 栏字体（`bar.fontFamily`，回退到 `Style.font.family`）
**Label/Mono Font:** 与宿主栏字体相同；当前视觉以紧凑等宽字形呈现遥测

**Character:** 字体服务于快速扫描而非品牌表演。数字、百分比、重置时间和成本保持紧密对齐；层级来自宿主的 `Style.font` 尺度、字重和大小写，而不是额外字体家族。

### Hierarchy

- **Title**（`Style.font.title`，bold）：CodexBar 或当前提供商标题，以及队列中的主用量百分比。
- **Body**（`Style.font.body`）：提供商详情中的窗口标题与积分值。
- **Body Small**（`Style.font.bodySmall`）：分段标签、空状态、成本行与刷新按钮。
- **Caption**（`Style.font.caption`）：状态、节标题、窗口元数据、剩余额度、重置时间与成本辅助行；状态和关键标签可加粗。

**The Telemetry Hierarchy Rule.** 最大、最重的数字永远是当前约束窗口的已用比例；提供商名、窗口名和恢复时间依次退后。

## Layout

CodexBar 以现有 Omarchy 右侧区域 `BarIconButton` 为入口；它不是一条独立 bar。点击入口打开锚定于该按钮的 `KeyboardPanel`。弹层的原生目标几何为 380×640 逻辑像素（`Style.space(380)` × `Style.space(640)`），超出高度时只在内容区垂直滚动。

首屏顺序固定为：连续动态分段轨道、细分隔线、紧凑状态 Hero、可选状态/错误提示、当前内容、细分隔线、更新时间与成本摘要、全宽刷新按钮。主要纵向节奏由 `Style.space(12)` 建立，队列与页脚内部使用更紧凑的 7–10 个 style-space 单位。

分段轨道始终是一整块连续边框表面：Overview 固定在首位，随后只出现服务成功返回的真实提供商。每段最小宽度为 `Style.space(84)`，轨道高度为 `Style.space(34)`；提供商过多时轨道水平滚动，不压缩到不可读。

Overview 中的提供商由最紧张的可用窗口按已用比例降序排列；相同比例再按提供商名排序。每行先显示绑定窗口，第二紧张窗口压成一行辅助信息。进入提供商页后，所有可用窗口、积分、当前成本和最近 30 天成本按数据存在性依次展示。

**The Constraint-First Rule.** 默认打开 Overview，并让最可能阻断下一次请求的提供商占据队列最前，而不是默认打开某个提供商或固定其位置。

## Elevation & Depth

系统保持平面，不使用渐变、玻璃、模糊、发光或大阴影。层级由宿主弹层表面、`BorderSurface` 的细边框、`PanelSeparator` 和低 alpha 状态填充建立；悬停和选择只改变局部色调，不产生抬升。

**The Flat Popup Rule.** 弹层内部不堆叠浮动卡片；队列项共享同一表面语境，由留白、游标状态和细分隔线区分。

## Shapes

所有容器和控件复用 `Style.cornerRadius`，不建立 CodexBar 专属圆角尺度。分段的内层选中面在宿主圆角上扣除 `Style.space(2)`；进度条两端使用半高圆角，状态指示器为圆点。整体轮廓偏克制，避免大胶囊、大卡片和高装饰性形状。

## Components

### Bar Entry

- 使用宿主已有右侧区域的 `BarIconButton`，图标与 Tooltip 承担唯一入口；不得渲染第二条 bar 或独立悬浮入口。
- 普通点击切换弹层；中键直接刷新。
- 服务失败或任一首要约束达到 90% 时进入 active 状态；失败时 Tooltip 明确为 connection failed。

### KeyboardPanel

- 锚定 Bar Entry，继承宿主 bar、弹层尺寸计算、焦点管理和跨面板切换行为。
- 打开时总是回到 Overview、队列首行和滚动顶部，并立即请求刷新。
- 内容区使用止于边界的 `Flickable`；只在内容超过视口时显示滚动条。

### Provider Segment Track

- 一块连续 `BorderSurface` 承载 Overview 与所有真实提供商分段。
- 选中态为低强度强调填充与强调色文字；悬停或键盘游标为 9% 前景色填充；分段间用 1px 细线连接。
- 标签来源于规范化后的服务记录；空 provider id、错误记录和重复记录被过滤，未知但非空的真实 provider id 会被安全地人类化后展示。

### Constraint Queue Row

- 每行显示提供商、绑定窗口已用/剩余比例、进度、窗口名、重置时间和可用时的第二窗口摘要。
- 行顺序由数据约束度决定；点击或键盘激活进入该提供商详情。
- 普通填充使用前景色，达到 90% 后主比例与填充同时切换为紧急色。
- 配额条宽度变化以 220ms `OutExpo` 动画响应新数据；分段色调以 100ms 过渡响应选择与悬停。

### Provider Detail

- 展示该提供商返回的全部有效限制窗口，并对每个窗口显示用量、剩余比例、重置时间和可用的 pace 摘要。
- 积分、当前/今日或会话成本、token、最近 30 天成本仅在字段存在时出现；缺失字段使用破折号或省略整个可选区域，不伪造数据。

### Service and Recovery States

- `stopped`、`starting`、`ready`、`error` 与 refreshing 映射为明确文案和状态点。
- 错误且仍有缓存提供商时显示 “SHOWING LAST DATA”；没有缓存时显示 “CONNECTION FAILED”。错误提示保留可理解的原因与 Retry 动作。
- ready 但无有效提供商时显示 “NO ACTIVE PROVIDERS” 和可恢复空状态；刷新期间禁用按钮并展示旋转图标。

### Input Behavior

- 左右方向键循环切换 Overview/提供商；Overview 中上下键移动队列游标，详情中上下键按 `Style.space(56)` 滚动。
- Enter/激活键在 Overview 打开当前提供商，在详情触发刷新；Escape 关闭；Tab/Shift+Tab 交给宿主切换面板。
- `R` 刷新，`O` 返回 Overview。鼠标支持分段点击、队列悬停/点击、滚轮/拖动滚动、Retry 与 Refresh 按钮。

## Do's and Don'ts

### Do:

- **Do** 从 Omarchy 的 `Color`、`Style`、`Border` 和现成 Ui 组件继承视觉与交互。
- **Do** 默认显示 constraint-sorted Overview，并只为服务成功记录生成提供商分段。
- **Do** 在 380×640 逻辑视口中优先保证状态、队列、更新时间、成本和刷新可扫描。
- **Do** 对缺失字段、短暂断线和刷新失败采取防御性呈现，并保留最后一次可用数据。
- **Do** 同时维持完整的鼠标与键盘路径。

### Don't:

- **Don't** 新建独立 bar、provider-first 默认页或固定提供商标签。
- **Don't** 用品牌彩虹、普通警示色或每提供商一色稀释 90% 紧急阈值。
- **Don't** 引入 macOS 玻璃、渐变、模糊、发光、大阴影或堆叠圆角卡片。
- **Don't** 为服务未返回的限制、成本、积分或提供商填充示意值。
- **Don't** 绕过宿主 token 硬编码当前主题的颜色、字体、间距或圆角。
