# Omarchy CodexBar

一个 Omarchy bar-widget 插件。它通过本机 `codexbar serve` 读取提供商用量，把最可能先阻止下一次请求的配额窗口排在前面。

## 面板行为

- 每次打开默认进入 **Overview**。
- 顶部只展示 `/usage?provider=all` 中成功返回的提供商；不会为未配置或失败记录创建空标签。
- Overview 按提供商当前最高 `usedPercent` 从高到低排列。点击一行进入该提供商详情。
- 详情页展示服务实际返回的全部配额窗口，以及可用的 credits 和 cost 数据。
- 中键点击托盘图标、面板中的按钮或键盘 `R` 可刷新；方向键或 `H/J/K/L` 可导航，`O` 返回 Overview。

## 服务生命周期

插件先检查 `http://127.0.0.1:<port>/health`：

1. 若已有健康的 CodexBar 服务，直接复用，插件不会停止它。
2. 若服务不存在，启动一个带 `--identity redacted` 的 `codexbar serve`，等待健康检查成功后才请求数据。
3. 插件销毁时只停止自己启动的进程；短暂断线会保留最后一次可用数据并自动重连。

默认端口 `8080` 来自当前 `codexbar serve` 的实际默认行为，可在插件设置中调整。端口、刷新间隔和请求超时都通过 manifest 暴露，不写入用户的 Omarchy 配置。

## 本地加载

要求系统中已安装 Omarchy 和 `codexbar`。

```bash
cd /path/to/omarchy-codexbar

PLUGIN_DIR="$HOME/.config/omarchy/plugins/community.codexbar"
install -d "$PLUGIN_DIR"
install -m 0644 manifest.json Panel.qml CodexBarService.qml Model.js "$PLUGIN_DIR/"

omarchy plugin validate "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins
omarchy plugin enable community.codexbar --section right
```

本地修改后，重新执行 `install` 和 `rescanPlugins` 两行即可热加载。`omarchy plugin add` 面向 Git URL，不接受本地目录。

## 验证

仓库检查：

```bash
omarchy plugin validate .
node --test tests/model.test.mjs
```

插件不会复制 CodexBar 的提供商鉴权或配额业务逻辑；`codexbar serve` 始终是服务状态、用量和成本数据的唯一事实来源。
