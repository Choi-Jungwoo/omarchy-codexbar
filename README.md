# Omarchy CodexBar

一个 Omarchy bar-widget 插件。它通过本机 `codexbar serve` 读取提供商用量，在系统托盘弹层中汇总最近 30 天支出、token、各提供商剩余额度，并提供 Codex Radar 的站长模型推荐。

## 面板行为

- Shell 启动后首次打开默认进入 **Overview**；关闭后再打开会恢复上次选中的 Overview、Radar 或提供商面板。若已记忆的提供商不在服务结果中，自动回退 Overview。
- 固定的 **Radar** 标签位于 Codex 后方（无 Codex 时紧跟 Overview），其他提供商始终排在 Radar 后面。它按需读取 Codex Radar 的场景推荐与效率指标，以窄面板账本展示模型/档位、IQ、平均耗时和平均费用，并沿用官网的补齐规则为四类场景各展示两条推荐；任一请求失败或结果不足两条时保留上次完整数据并进入可重试错误态。规则说明可悬停查看，顶部标签轨道不会随长内容滚走。
- Overview 在 30 天价格数字下方从同一份 Radar 数据中提取 `Daily development` 与 `Hard problems` 的首选模型，以同一行展示模型/档位和 IQ；整行可直接进入完整 Radar 标签。
- 顶部只展示 `/usage?provider=all` 中成功返回的提供商；不会为未配置或失败记录创建空标签。
- Overview 先展示最近 30 天总支出、token 与成本数据覆盖的提供商数量；Codex 固定在列表首位，其他提供商保持原有约束顺序。
- 所有配额条表示**剩余比例**，使用当前 Omarchy 主题强调色；低于或等于 10% 时才使用紧急色。服务返回 `expectedUsedPercent` 时，条上的动态刻度表示当前 pace 对应的预计剩余比例。
- 只有 Codex 行会在鼠标悬停或键盘游标落入时展开账号、套餐、全部窗口、剩余重置次数及最早到期时间、今日/会话成本、30 天成本和日用量历史；其他提供商保持紧凑。Codex 独立页同样展示打码账号、套餐、全部配额与 pace、reset credits 及最早截止时间、成本拆分和日历史；后端未返回 reset credits 时显示明确的 unavailable 状态。账号邮箱只保留少量开头字符和域名，其余本地部分用圆点遮盖。点击任一行仍可进入该提供商详情。
- 面板使用更长的目标高度，主内容在固定标签轨道与固定页脚之间独立滚动；窄滚动条贴最右侧，内容左右间距保持一致，`UPDATE`、`COST` 与刷新操作始终固定在底部。
- 中键点击托盘图标、面板中的按钮或键盘 `R` 可刷新；方向键或 `H/J/K/L` 可导航，`O` 返回 Overview。再次点击托盘图标、点击面板外部或按 `Escape` 都只关闭弹层，不会退出 Omarchy Shell 或停止 CodexBar 服务。

## 服务生命周期

插件先检查 `http://127.0.0.1:<port>/health`：

1. 若已有健康的 CodexBar 服务，直接复用，插件不会停止它。
2. 若服务不存在，启动一个带 `--identity redacted` 的 `codexbar serve`，等待健康检查成功后才请求数据。
3. 插件销毁时只停止自己启动的进程；短暂断线会保留最后一次可用数据并自动重连。

默认端口 `8080` 来自当前 `codexbar serve` 的实际默认行为，可在插件设置中调整。端口、刷新间隔和请求超时都通过 manifest 暴露，不写入用户的 Omarchy 配置。

## 安装

要求系统中已安装 Omarchy 和 `codexbar`。

当前 GitHub 仓库是私有仓库，先让 Git 使用 GitHub CLI 的登录凭据：

```bash
gh auth login
gh auth setup-git
```

然后从 GitHub 安装并启用插件：

```bash
omarchy plugin add https://github.com/Choi-Jungwoo/omarchy-codexbar.git --enable --yes
```

插件会按 manifest 的 `defaultSection: right` 出现在 Omarchy 顶栏右侧。更新已安装版本：

```bash
omarchy plugin update community.codexbar --yes
```

## 本地开发加载

在仓库目录中执行：

```bash
cd /path/to/omarchy-codexbar

PLUGIN_DIR="$HOME/.config/omarchy/plugins/community.codexbar"
install -d "$PLUGIN_DIR"
install -m 0644 manifest.json Panel.qml CodexBarService.qml CodexRadarService.qml Model.js "$PLUGIN_DIR/"

omarchy plugin validate "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins
omarchy plugin enable community.codexbar --section right
```

本地修改后，重新执行 `install` 和 `rescanPlugins` 两行即可热加载。如果已打开的面板仍保留旧 QML 实例，执行 `omarchy restart shell` 强制重建插件。`omarchy plugin add` 面向 Git URL，不接受本地目录。

## 验证

仓库检查：

```bash
omarchy plugin validate .
node --test tests/model.test.mjs
```

插件不会复制 CodexBar 的提供商鉴权或配额业务逻辑；`codexbar serve` 始终是服务状态、用量和成本数据的唯一事实来源。Radar 标签的数据来自 [Codex Radar](https://codexradar.com/)，当前并行读取其页面公开的推荐与效率指标接口，在适配层沿用官网的候选过滤、排序和补齐逻辑，并在面板内保留来源标注；Codex Radar 对完整 JSON API 与二次开发另有授权要求，分发或商业化使用前请先向站长取得授权。
