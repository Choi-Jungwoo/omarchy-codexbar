/*
THESIS: One tray surface joins truthful usage with compact first-glance picks and a full Radar recommendation ledger.
OWN-WORLD: Omarchy theme tokens, flat popup surfaces, fine dividers, compact mono typography, restrained accent, and urgent color only for risk.
STORY: Read the 30-day total, see the daily-development and hard-problem picks with IQ directly beneath it, then scan usage or open Radar for the full comparison.
FIRST VIEWPORT: A 380×720 tray panel fixes Overview, Codex, and Radar tabs at the top; one compact two-pick Radar row follows the Overview total, while contextual ledgers scroll between the fixed tab rail and footer controls.
FORM: Usage Ledger extended with an English recommendation ledger, preserving the established Omarchy visual world.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
*/

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  moduleName: "community.codexbar"
  ipcTarget: "community.codexbar"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  // The global muted token can be intentionally faint for decorative chrome.
  // Usage metadata is body copy, so derive it from this panel's foreground to
  // keep reset times and remaining amounts readable on every popup surface.
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.66)
  readonly property color track: Style.selectedFillFor(foreground, accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var providers: service.providers
  readonly property var overviewProviders: Model.overviewProviders(providers)
  readonly property var overviewSummary: Model.last30DaysSummary(providers)
  readonly property var viewTabs: Model.viewTabs(providers)
  readonly property var dailyDevelopmentPick: firstRadarPick("daily_development", radarService.groups)
  readonly property var hardProblemsPick: firstRadarPick("hard_problems", radarService.groups)
  readonly property bool hasCodex: providerForId("codex") !== null
  property string selectedViewId: "overview"
  property int queueCursor: 0
  property bool cursorActive: false
  property bool keyboardCursorActive: false
  property double nowMs: Date.now()

  readonly property var selectedProvider: providerForId(selectedViewId)
  readonly property bool radarSelected: selectedViewId === "radar"
  readonly property bool alarming: providers.length > 0 && providers[0].bindingWindow
    && providers[0].bindingWindow.usedPercent >= 90
  readonly property bool failed: service.status === "error"
  readonly property bool viewFailed: radarSelected ? radarService.status === "error" : failed
  readonly property bool viewRefreshing: radarSelected ? radarService.refreshing : service.refreshing
  readonly property string footerCost: Model.costSummary(providers)

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
  }

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function providerForId(providerId) {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === providerId) return providers[i]
    return null
  }

  function firstRadarPick(key, groups) {
    for (var i = 0; i < groups.length; i++) {
      var group = groups[i]
      if (group.key === key && group.items.length > 0) return group.items[0]
    }
    return null
  }

  function selectedTabIndex() {
    for (var i = 0; i < viewTabs.length; i++)
      if (viewTabs[i].viewId === selectedViewId) return i
    return 0
  }

  function selectTab(index) {
    var count = viewTabs.length
    if (count <= 0) return
    var wrapped = ((index % count) + count) % count
    selectedViewId = viewTabs[wrapped].viewId
    queueCursor = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  function openProvider(providerId) {
    if (!providerForId(providerId)) return
    selectedViewId = providerId
    queueCursor = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  function statusLabel() {
    if (radarSelected) {
      if (radarService.refreshing) return "REFRESHING"
      if (radarService.status === "error") return radarService.groups.length > 0 ? "SHOWING LAST DATA" : "RADAR UNAVAILABLE"
      if (radarService.status === "idle" || radarService.status === "loading") return "LOADING RADAR"
      if (radarService.groups.length === 0) return "NO RECOMMENDATIONS"
      return radarService.groups.length + (radarService.groups.length === 1 ? " GROUP READY" : " GROUPS READY")
    }
    if (service.status === "stopped") return "SERVICE STOPPED"
    if (service.status === "starting") return "CONNECTING"
    if (service.status === "error") return providers.length > 0 ? "SHOWING LAST DATA" : "CONNECTION FAILED"
    if (service.refreshing) return "REFRESHING"
    if (alarming) return "LIMIT ATTENTION"
    if (providers.length === 0) return "NO ACTIVE PROVIDERS"
    return providers.length + (providers.length === 1 ? " PROVIDER READY" : " PROVIDERS READY")
  }

  function statusColor() {
    if (viewFailed || (!radarSelected && alarming)) return urgent
    if (radarSelected ? radarService.status === "ready" : service.status === "ready") return foreground
    return dim
  }

  function statusHelp() {
    if (radarSelected) {
      if (radarService.refreshing) return ""
      if (radarService.status === "error") return radarService.lastError || "Codex Radar is unavailable. Retry when the network is ready."
      if (radarService.status === "ready" && radarService.groups.length === 0)
        return "Codex Radar returned no current recommendations. Refresh to check again."
      return ""
    }
    if (service.status === "starting") return "Waiting for the local CodexBar service…"
    if (service.status === "error") return service.lastError || "CodexBar is unavailable. Retry when the service is ready."
    if (providers.length === 0) return "CodexBar returned no usable provider records yet. Use a provider, then refresh."
    return ""
  }

  function latestUpdatedLabel() {
    var value = radarSelected
      ? (radarService.sourceUpdatedAt || radarService.generatedAt)
      : service.lastUpdatedAt
    return Model.updatedLabel(value, nowMs)
  }

  function ensureSelection() {
    if (selectedViewId !== "overview" && selectedViewId !== "radar" && !providerForId(selectedViewId))
      selectedViewId = "overview"
    queueCursor = clamp(queueCursor, 0, Math.max(0, providers.length - 1))
  }

  function refreshCurrentView() {
    if (radarSelected) radarService.refreshNow()
    else service.refreshNow()
  }

  function moveVertical(delta) {
    cursorActive = true
    keyboardCursorActive = true
    if (selectedViewId === "overview" && overviewProviders.length > 0) {
      queueCursor = clamp(queueCursor + delta, 0, overviewProviders.length - 1)
      return
    }
    panelFlick.contentY = clamp(panelFlick.contentY + delta * Style.space(56), 0,
      Math.max(0, panelFlick.contentHeight - panelFlick.height))
  }

  function activateCursor() {
    if (selectedViewId === "overview" && overviewProviders.length > 0) openProvider(overviewProviders[queueCursor].providerId)
    else refreshCurrentView()
  }

  onProvidersChanged: ensureSelection()
  onSelectedViewIdChanged: {
    queueCursor = 0
    if (panelFlick) panelFlick.contentY = 0
    if (opened && radarSelected) radarService.refreshIfStale()
  }
  onOpenedChanged: if (opened) {
    ensureSelection()
    queueCursor = 0
    cursorActive = false
    keyboardCursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    refreshCurrentView()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  CodexBarService {
    id: service
    settings: root.settings
  }

  CodexRadarService {
    id: radarService
    settings: root.settings
    active: root.opened
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshCurrentView(); return "ok" }
    function overview(): string { root.selectedViewId = "overview"; return "ok" }
    function radar(): string { root.selectedViewId = "radar"; return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱚣"
    tooltipText: root.failed ? "CodexBar · connection failed" : "CodexBar · provider usage"
    active: root.failed || root.alarming
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) service.refreshNow()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.cappedContentHeight(Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.keyboardCursorActive = true
          root.selectTab(root.selectedTabIndex() + dx)
        }
        if (dy !== 0) root.moveVertical(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refreshCurrentView()
        if (text === "o" || text === "O") root.selectedViewId = "overview"
      }

      Column {
        id: fixedHeaderColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        Flickable {
          id: tabsFlick
          width: parent.width
          implicitHeight: tabsTrack.implicitHeight
          contentWidth: tabsTrack.width
          contentHeight: height
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.HorizontalFlick
          interactive: contentWidth > width

          BorderSurface {
            id: tabsTrack
            width: Math.max(tabsFlick.width, root.viewTabs.length * Style.space(84))
            implicitHeight: Style.space(34)
            color: "transparent"
            borderSpec: Border.flat(root.alpha(root.foreground, 0.32), 1)
            radius: Style.cornerRadius

            Row {
              anchors.fill: parent

              Repeater {
                model: root.viewTabs

                TabSegment {
                  required property var modelData
                  required property int index
                  label: modelData.label
                  providerId: modelData.viewId
                  tabIndex: index
                  width: tabsTrack.width / Math.max(1, root.viewTabs.length)
                }
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }
      }

      Flickable {
        id: panelFlick
        anchors {
          top: fixedHeaderColumn.bottom
          topMargin: Style.space(12)
          left: parent.left
          right: parent.right
          bottom: footerColumn.top
          bottomMargin: Style.space(12)
        }
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroTitle.implicitHeight + heroMeta.implicitHeight + Style.space(3), heroStatus.implicitHeight)

            Column {
              anchors.left: parent.left
              anchors.right: heroStatus.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              Text {
                id: heroTitle
                width: parent.width
                text: root.selectedViewId === "overview"
                  ? "Usage & spend · 30 days"
                  : (root.radarSelected
                    ? "Editor's picks · Codex Radar"
                    : (root.selectedProvider ? root.selectedProvider.providerName : "CodexBar"))
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                id: heroMeta
                width: parent.width
                text: root.selectedViewId === "overview"
                  ? root.latestUpdatedLabel()
                  : (root.radarSelected
                    ? "Measured IQ, average time, and cost"
                    : (root.selectedProvider && root.selectedProvider.source ? root.selectedProvider.source : "Provider usage"))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Row {
              id: heroStatus
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Rectangle {
                width: Style.space(6)
                height: width
                radius: width / 2
                color: root.statusColor()
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.statusLabel()
                color: root.statusColor()
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          BorderSurface {
            visible: root.statusHelp() !== ""
            width: parent.width
            implicitHeight: Math.max(statusMessage.implicitHeight, retryButton.implicitHeight) + Style.space(12)
            color: root.viewFailed ? root.alpha(root.urgent, 0.10) : root.alpha(root.foreground, 0.05)
            borderSpec: Border.flat(root.viewFailed ? root.alpha(root.urgent, 0.35) : root.alpha(root.foreground, 0.18), 1)
            radius: Style.cornerRadius

            Text {
              id: statusMessage
              anchors.left: parent.left
              anchors.right: retryButton.visible ? retryButton.left : parent.right
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: root.statusHelp()
              color: root.viewFailed ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              id: retryButton
              visible: root.viewFailed || (!root.radarSelected && service.status === "stopped")
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              text: "Retry"
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.space(4)
              onClicked: root.radarSelected ? radarService.refreshNow() : service.probe()
            }
          }

          Loader {
            width: parent.width
            sourceComponent: root.radarSelected
              ? radarContent
              : (root.selectedViewId === "overview" ? overviewContent : providerContent)
          }
        }
      }

      Column {
        id: footerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Style.space(8)

        PanelSeparator { foreground: root.foreground }

            Item {
              width: parent.width
              implicitHeight: Math.max(updateGroup.implicitHeight, costGroup.implicitHeight)

              Column {
                id: updateGroup
                anchors.left: parent.left
                anchors.right: costGroup.left
                anchors.rightMargin: Style.space(16)
                spacing: Style.space(2)

                PanelSectionHeader {
                  text: "UPDATE"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }
                Text {
                  width: parent.width
                  text: root.latestUpdatedLabel().replace(/^Updated\s*/, "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Column {
                id: costGroup
                width: Math.min(parent.width * 0.58, Math.max(costHeader.implicitWidth, costValue.implicitWidth))
                anchors.right: parent.right
                spacing: Style.space(2)

                PanelSectionHeader {
                  id: costHeader
                  width: parent.width
                  text: root.radarSelected ? "SOURCE" : "COST"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  horizontalAlignment: Text.AlignRight
                }
                Text {
                  id: costValue
                  width: parent.width
                  text: root.radarSelected ? "Codex Radar" : root.footerCost
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideLeft
                }
              }
            }

            Button {
              width: parent.width
              text: root.viewRefreshing
                ? (root.radarSelected ? "Refreshing recommendations…" : "Refreshing usage…")
                : (root.radarSelected ? "Refresh recommendations" : "Refresh usage")
              iconText: root.viewRefreshing ? "󰑐" : ""
              iconSpinning: root.viewRefreshing
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              enabled: !root.viewRefreshing
              opacity: enabled ? 1 : 0.55
              onClicked: root.refreshCurrentView()
            }

            Button {
              width: parent.width
              text: "Exit panel"
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: root.close()
            }
          }
        }

        ScrollBar {
          id: panelScrollBar
          parent: keyCatcher
          x: keyCatcher.width + panel.padding - width
          y: panelFlick.y
          width: Style.space(3)
          height: panelFlick.height
          orientation: Qt.Vertical
          size: panelFlick.visibleArea.heightRatio
          visible: size < 1
          active: visible
          z: 20

          background: Rectangle {
            radius: width / 2
            color: root.alpha(root.foreground, 0.10)
          }
          contentItem: Rectangle {
            radius: width / 2
            color: panelScrollBar.pressed
              ? root.foreground
              : root.alpha(root.foreground, 0.48)
          }

          Binding {
            target: panelScrollBar
            property: "position"
            value: panelFlick.visibleArea.yPosition
            when: !panelScrollBar.pressed
          }

          onPositionChanged: if (pressed) {
            panelFlick.contentY = position * Math.max(0, panelFlick.contentHeight)
          }
        }
      }

  component UsageMeter: Item {
    id: meter
    property real value: 0
    property bool alarming: false
    property real markerValue: -1
    property color fillColor: root.accent
    property real thickness: Math.max(Style.space(5), Math.round(Style.spacing.controlHeight * 0.16))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
      clip: true

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * root.clamp(meter.value / 100, 0, 1)
        radius: parent.radius
        color: meter.alarming ? root.urgent : meter.fillColor

        Behavior on width {
          NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
        }
      }

      Rectangle {
        visible: meter.markerValue >= 0 && meter.markerValue <= 100
        x: Math.round(parent.width * root.clamp(meter.markerValue / 100, 0, 1) - width / 2)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(1, Style.space(2))
        color: Color.popups.background

        Behavior on x {
          NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
        }
      }
    }
  }

  component TabSegment: Item {
    id: tabSegment
    property string label: ""
    property string providerId: ""
    property int tabIndex: 0

    readonly property bool selected: root.selectedViewId === providerId
    readonly property bool hasCursor: root.cursorActive && root.selectedTabIndex() === tabIndex

    height: parent ? parent.height : 0

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Math.max(0, Style.cornerRadius - Style.space(2))
      color: tabSegment.selected
        ? root.alpha(root.accent, 0.22)
        : (segmentMouse.containsMouse || tabSegment.hasCursor ? root.alpha(root.foreground, 0.09) : "transparent")

      Behavior on color { ColorAnimation { duration: 100 } }
    }

    Rectangle {
      visible: tabSegment.tabIndex > 0
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: Style.space(5)
      anchors.bottomMargin: Style.space(5)
      width: 1
      color: root.alpha(root.foreground, 0.24)
    }

    Text {
      anchors.centerIn: parent
      text: tabSegment.label
      color: tabSegment.selected ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: tabSegment.selected
    }

    MouseArea {
      id: segmentMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.keyboardCursorActive = false
      }
      onClicked: root.selectTab(tabSegment.tabIndex)
    }
  }

  component CompactLimitRow: Column {
    id: compactLimit
    property var window: null
    property bool showPace: false

    readonly property bool limitAlarming: window && window.usedPercent >= 90

    width: parent ? parent.width : 0
    spacing: Style.space(4)

    Item {
      width: parent.width
      implicitHeight: Math.max(compactTitle.implicitHeight, compactReset.implicitHeight)

      Text {
        id: compactTitle
        anchors.left: parent.left
        anchors.right: compactReset.left
        anchors.rightMargin: Style.space(8)
        text: compactLimit.window
          ? compactLimit.window.title.toUpperCase() + " · "
            + Model.formatPercent(compactLimit.window.remainingPercent) + " LEFT"
          : ""
        color: compactLimit.limitAlarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        id: compactReset
        anchors.right: parent.right
        text: compactLimit.window ? Model.resetLabel(compactLimit.window, root.nowMs).toUpperCase() : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    UsageMeter {
      width: parent.width
      value: compactLimit.window ? compactLimit.window.remainingPercent : 0
      markerValue: compactLimit.window && compactLimit.window.expectedRemainingPercent !== null
        ? compactLimit.window.expectedRemainingPercent
        : -1
      alarming: compactLimit.limitAlarming
      thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.12))
    }

    Text {
      visible: compactLimit.showPace && text !== ""
      width: parent.width
      text: compactLimit.window ? compactLimit.window.paceSummary : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  component DailyCostChart: Column {
    id: dailyChart
    property var days: []
    readonly property var chartDays: days && days.length > 7 ? days.slice(days.length - 7) : (days || [])
    readonly property real maximum: Model.dailyMaximum(chartDays)

    width: parent ? parent.width : 0
    spacing: Style.space(4)

    Item {
      id: chartPlot
      width: parent.width
      implicitHeight: Style.space(58)

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.alpha(root.foreground, 0.18)
      }

      Row {
        anchors.fill: parent
        spacing: Style.space(4)

        Repeater {
          model: dailyChart.chartDays

          Item {
            required property var modelData
            width: (chartPlot.width - Math.max(0, dailyChart.chartDays.length - 1) * Style.space(4))
              / Math.max(1, dailyChart.chartDays.length)
            height: chartPlot.height

            readonly property real barValue: modelData.costUSD !== null ? modelData.costUSD : modelData.tokens

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: dailyChart.maximum > 0
                ? Math.max(Style.space(3), parent.height * parent.barValue / dailyChart.maximum)
                : Style.space(3)
              radius: Math.min(Style.cornerRadius, width / 3)
              color: root.alpha(root.foreground, 0.82)

              Behavior on height {
                NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
              }
            }
          }
        }
      }

    }

    Item {
      visible: dailyChart.chartDays.length > 0
      width: parent.width
      implicitHeight: Math.max(firstDay.implicitHeight, lastDay.implicitHeight)

      Text {
        id: firstDay
        anchors.left: parent.left
        text: dailyChart.chartDays.length > 0 ? dailyChart.chartDays[0].label : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        id: lastDay
        anchors.right: parent.right
        text: dailyChart.chartDays.length > 0 ? dailyChart.chartDays[dailyChart.chartDays.length - 1].label : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  component OverviewProviderRow: CursorSurface {
    id: providerRow
    property var provider: null
    property int rowIndex: 0

    readonly property var headline: provider ? provider.bindingWindow : null
    readonly property bool isCodex: provider && provider.providerId === "codex"
    readonly property bool expanded: isCodex
      && (providerMouse.containsMouse || (root.keyboardCursorActive && hasCursor))

    implicitHeight: providerContent.implicitHeight + Style.space(18)
    radius: Style.cornerRadius
    foreground: root.foreground
    accent: root.accent
    hasCursor: root.cursorActive && root.selectedViewId === "overview" && root.queueCursor === rowIndex
    clip: true

    Behavior on implicitHeight {
      NumberAnimation { duration: 180; easing.type: Easing.OutExpo }
    }

    Column {
      id: providerContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(7)

      Item {
        width: parent.width
        implicitHeight: Math.max(providerName.implicitHeight, providerIdentity.implicitHeight)

        Text {
          id: providerName
          anchors.left: parent.left
          anchors.right: providerIdentity.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: providerRow.provider ? providerRow.provider.providerName.toUpperCase() : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          id: providerIdentity
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: providerRow.expanded && providerRow.provider
            ? [providerRow.provider.accountLabel, providerRow.provider.planLabel].filter(function(value) { return value !== "" }).join(" · ")
            : (providerRow.headline ? Model.formatPercent(providerRow.headline.remainingPercent) + " LEFT" : "NO LIMIT")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideLeft
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(7)

        Repeater {
          model: providerRow.provider ? providerRow.provider.windows : []

          CompactLimitRow {
            required property var modelData
            window: modelData
            showPace: providerRow.expanded
          }
        }
      }

      Text {
        visible: providerRow.provider && providerRow.provider.windows.length === 0
        width: parent.width
        text: "Rate-limit data is unavailable."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Column {
        visible: providerRow.expanded
        width: parent.width
        spacing: Style.space(8)

        PanelSeparator { foreground: root.foreground }

        Item {
          visible: providerRow.provider && (!!providerRow.provider.resetCredits || !!providerRow.provider.credits)
          width: parent.width
          implicitHeight: Math.max(creditLabel.implicitHeight, creditValue.implicitHeight)

          Text {
            id: creditLabel
            anchors.left: parent.left
            anchors.top: parent.top
            text: providerRow.provider && providerRow.provider.resetCredits ? "RESET CREDITS" : "CREDITS"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Column {
            id: creditValue
            anchors.right: parent.right
            width: Math.min(parent.width * 0.68, Math.max(creditCount.implicitWidth, creditExpiry.implicitWidth))
            spacing: Style.space(2)

            Text {
              id: creditCount
              width: parent.width
              text: providerRow.provider && providerRow.provider.resetCredits
                ? Math.round(providerRow.provider.resetCredits.availableCount) + " AVAILABLE"
                : (providerRow.provider && providerRow.provider.credits
                  ? Model.formatMoney(providerRow.provider.credits.remaining) + " REMAINING"
                  : "")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }

            Text {
              id: creditExpiry
              visible: providerRow.provider && providerRow.provider.resetCredits
                && providerRow.provider.resetCredits.expiresAt !== ""
              width: parent.width
              text: visible
                ? Model.expiryLabel(providerRow.provider.resetCredits.expiresAt, root.nowMs).toUpperCase()
                : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        Item {
          visible: providerRow.provider && !!providerRow.provider.cost
          width: parent.width
          implicitHeight: Math.max(currentCost.implicitHeight, monthCostOverview.implicitHeight)

          Column {
            id: currentCost
            anchors.left: parent.left
            width: (parent.width - Style.space(16)) / 2
            spacing: Style.space(2)

            PanelSectionHeader {
              text: providerRow.provider && providerRow.provider.cost
                ? providerRow.provider.cost.summaryLabel.toUpperCase()
                : "CURRENT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              width: parent.width
              text: providerRow.provider && providerRow.provider.cost
                ? Model.formatMoney(providerRow.provider.cost.summaryCostUSD)
                : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              width: parent.width
              text: providerRow.provider && providerRow.provider.cost
                ? Model.formatTokens(providerRow.provider.cost.summaryTokens) + " tokens"
                : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            id: monthCostOverview
            anchors.right: parent.right
            width: (parent.width - Style.space(16)) / 2
            spacing: Style.space(2)

            PanelSectionHeader {
              width: parent.width
              text: "30 DAYS"
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalAlignment: Text.AlignRight
            }
            Text {
              width: parent.width
              text: providerRow.provider && providerRow.provider.cost
                ? Model.formatMoney(providerRow.provider.cost.last30DaysCostUSD)
                : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }
            Text {
              width: parent.width
              text: providerRow.provider && providerRow.provider.cost
                ? Model.formatTokens(providerRow.provider.cost.last30DaysTokens) + " tokens"
                : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        DailyCostChart {
          visible: providerRow.provider && providerRow.provider.cost
            && providerRow.provider.cost.daily.length > 0
          width: parent.width
          days: providerRow.provider && providerRow.provider.cost ? providerRow.provider.cost.daily : []
        }
      }
    }

    MouseArea {
      id: providerMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.keyboardCursorActive = false
        root.queueCursor = providerRow.rowIndex
      }
      onClicked: if (providerRow.provider) root.openProvider(providerRow.provider.providerId)
    }
  }

  component LimitRow: Column {
    id: limitRow
    property var window: null

    readonly property bool limitAlarming: window && window.usedPercent >= 90
    width: parent ? parent.width : 0
    spacing: Style.space(7)

    Item {
      width: parent.width
      implicitHeight: Math.max(limitTitle.implicitHeight, limitUsed.implicitHeight)

      Text {
        id: limitTitle
        anchors.left: parent.left
        anchors.right: limitUsed.left
        anchors.rightMargin: Style.space(10)
        text: limitRow.window ? limitRow.window.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        id: limitUsed
        anchors.right: parent.right
        text: limitRow.window ? Model.formatPercent(limitRow.window.remainingPercent) + " left" : ""
        color: limitRow.limitAlarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    UsageMeter {
      width: parent.width
      value: limitRow.window ? limitRow.window.remainingPercent : 0
      markerValue: limitRow.window && limitRow.window.expectedRemainingPercent !== null
        ? limitRow.window.expectedRemainingPercent
        : -1
      alarming: limitRow.limitAlarming
    }

    Text {
      width: parent.width
      text: limitRow.window
        ? Model.formatPercent(limitRow.window.usedPercent) + " used · " + Model.resetLabel(limitRow.window, root.nowMs)
        : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      visible: text !== ""
      width: parent.width
      text: limitRow.window ? limitRow.window.paceSummary : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  component RadarMetricRow: Item {
    id: radarRow
    property var recommendation: null

    implicitHeight: Math.max(radarModel.implicitHeight, radarIq.implicitHeight,
      radarDuration.implicitHeight, radarCost.implicitHeight) + Style.space(14)

    Text {
      id: radarModel
      anchors.left: parent.left
      anchors.right: radarIq.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: radarRow.recommendation ? radarRow.recommendation.label : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      id: radarIq
      width: Style.space(42)
      anchors.right: radarDuration.left
      anchors.verticalCenter: parent.verticalCenter
      text: radarRow.recommendation && radarRow.recommendation.iq !== null
        ? String(Math.round(radarRow.recommendation.iq))
        : "—"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }

    Text {
      id: radarDuration
      width: Style.space(60)
      anchors.right: radarCost.left
      anchors.verticalCenter: parent.verticalCenter
      text: radarRow.recommendation && radarRow.recommendation.durationMinutes !== null
        ? Math.round(radarRow.recommendation.durationMinutes) + " min"
        : "—"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }

    Text {
      id: radarCost
      width: Style.space(66)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: radarRow.recommendation ? Model.formatMoney(radarRow.recommendation.costUSD) : "—"
      color: radarRow.recommendation && radarRow.recommendation.costUSD !== null ? root.accent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }

  component RadarRecommendationGroup: Column {
    id: radarGroup
    property var recommendationGroup: null

    width: parent ? parent.width : 0
    spacing: 0

    Item {
      width: parent.width
      implicitHeight: Math.max(radarGroupTitle.implicitHeight, radarRule.implicitHeight)
        + Style.space(10)

      Text {
        id: radarGroupTitle
        anchors.left: parent.left
        anchors.right: radarRule.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: radarGroup.recommendationGroup ? radarGroup.recommendationGroup.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        elide: Text.ElideRight
      }

      Rectangle {
        id: radarRule
        width: Style.space(20)
        height: width
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: ruleMouse.containsMouse ? root.alpha(root.accent, 0.18) : "transparent"
        border.width: 1
        border.color: ruleMouse.containsMouse ? root.accent : root.alpha(root.foreground, 0.36)

        Text {
          anchors.centerIn: parent
          text: "i"
          color: ruleMouse.containsMouse ? root.accent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        MouseArea {
          id: ruleMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.WhatsThisCursor
        }

        ToolTip.visible: ruleMouse.containsMouse && radarGroup.recommendationGroup
          && radarGroup.recommendationGroup.rule !== ""
        ToolTip.text: radarGroup.recommendationGroup ? radarGroup.recommendationGroup.rule : ""
        ToolTip.delay: 300
      }
    }

    Item {
      width: parent.width
      implicitHeight: radarColumnModel.implicitHeight + Style.space(9)

      Text {
        id: radarColumnModel
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(5)
        text: "MODEL / EFFORT"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        width: Style.space(42)
        anchors.right: radarColumnDuration.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(5)
        text: "IQ"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
      Text {
        id: radarColumnDuration
        width: Style.space(60)
        anchors.right: radarColumnCost.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(5)
        text: "TIME"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
      Text {
        id: radarColumnCost
        width: Style.space(66)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(5)
        text: "COST"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
    }

    PanelSeparator { width: parent.width; foreground: root.foreground }

    Repeater {
      model: radarGroup.recommendationGroup ? radarGroup.recommendationGroup.items : []

      Column {
        required property var modelData
        required property int index
        width: parent.width

        RadarMetricRow {
          width: parent.width
          recommendation: modelData
        }

        PanelSeparator {
          visible: radarGroup.recommendationGroup
            && index < radarGroup.recommendationGroup.items.length - 1
          width: parent.width
          foreground: root.foreground
        }
      }
    }
  }

  component OverviewRadarPickCell: Rectangle {
    id: overviewPickCell
    property string category: ""
    property var recommendation: null

    visible: recommendation !== null
    implicitHeight: overviewPickText.implicitHeight + Style.space(8)
    radius: Style.cornerRadius
    color: overviewPickMouse.containsMouse ? root.alpha(root.foreground, 0.07) : "transparent"

    Text {
      id: overviewPickText
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(4)
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      text: overviewPickCell.recommendation
        ? overviewPickCell.category.toUpperCase() + " · " + overviewPickCell.recommendation.label + " · IQ "
          + (overviewPickCell.recommendation.iq === null ? "—" : Math.round(overviewPickCell.recommendation.iq))
        : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }

    MouseArea {
      id: overviewPickMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.selectedViewId = "radar"
    }
  }

  Component {
    id: radarContent

    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(10)

      Text {
        visible: radarService.groups.length > 0
        width: parent.width
        text: "Data from Codex Radar · codexradar.com"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
      }

      Repeater {
        model: radarService.groups

        Column {
          required property var modelData
          required property int index
          width: parent.width
          spacing: Style.space(10)

          RadarRecommendationGroup {
            width: parent.width
            recommendationGroup: modelData
          }

          PanelSeparator {
            visible: index < radarService.groups.length - 1
            width: parent.width
            foreground: root.foreground
          }
        }
      }

      Text {
        visible: radarService.groups.length === 0
        width: parent.width
        topPadding: Style.space(28)
        bottomPadding: Style.space(28)
        text: radarService.refreshing
          ? "Loading model recommendations…"
          : (radarService.status === "error"
            ? "Recommendations are unavailable. Check the network, then retry."
            : "No model recommendations are available right now.")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
    }
  }

  Component {
    id: overviewContent

    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(10)

      Item {
        visible: root.overviewSummary.hasCost || root.overviewSummary.hasTokens
        width: parent.width
        implicitHeight: Math.max(monthTotal.implicitHeight, monthCoverage.implicitHeight)

        Text {
          id: monthTotal
          anchors.left: parent.left
          anchors.right: monthCoverage.left
          anchors.rightMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          text: root.overviewSummary.hasCost
            ? Model.formatMoney(root.overviewSummary.costUSD)
            : Model.formatTokens(root.overviewSummary.tokens) + " tokens"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.round(Style.font.title * 1.35)
          font.bold: true
          elide: Text.ElideRight
        }

        Column {
          id: monthCoverage
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: root.overviewSummary.costProviderCount + "/" + root.overviewSummary.providerCount + " PROVIDERS"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }
          Text {
            visible: root.overviewSummary.hasTokens
            text: Model.formatTokens(root.overviewSummary.tokens) + " TOKENS"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      Row {
        id: overviewRadarPicks
        visible: root.dailyDevelopmentPick !== null || root.hardProblemsPick !== null
        width: parent.width
        spacing: Style.space(8)

        OverviewRadarPickCell {
          width: root.hardProblemsPick !== null
            ? (overviewRadarPicks.width - overviewRadarPicks.spacing) / 2
            : overviewRadarPicks.width
          category: "Daily"
          recommendation: root.dailyDevelopmentPick
        }

        OverviewRadarPickCell {
          width: root.dailyDevelopmentPick !== null
            ? (overviewRadarPicks.width - overviewRadarPicks.spacing) / 2
            : overviewRadarPicks.width
          category: "Hard"
          recommendation: root.hardProblemsPick
        }
      }

      Text {
        visible: root.providers.length > 0 && !root.overviewSummary.hasCost && !root.overviewSummary.hasTokens
        width: parent.width
        text: "30-day cost data is unavailable for the active providers."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      PanelSeparator {
        visible: root.providers.length > 0
        width: parent.width
        foreground: root.foreground
      }

      PanelSectionHeader {
        visible: root.providers.length > 0
        text: root.hasCodex ? "PROVIDERS · HOVER CODEX FOR DETAILS" : "PROVIDERS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.overviewProviders

        Column {
          required property var modelData
          required property int index
          width: parent.width
          spacing: Style.space(8)

          OverviewProviderRow {
            width: parent.width
            provider: modelData
            rowIndex: index
          }

          PanelSeparator {
            visible: index < root.overviewProviders.length - 1
            width: parent.width
            foreground: root.foreground
          }
        }
      }

      Text {
        visible: root.providers.length === 0 && service.status === "ready"
        width: parent.width
        topPadding: Style.space(22)
        bottomPadding: Style.space(22)
        text: "No provider usage is available.\nUse a CodexBar-supported provider, then refresh."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
    }
  }

  Component {
    id: providerContent

    Column {
      id: detail
      width: parent ? parent.width : 0
      spacing: Style.space(12)
      readonly property var provider: root.selectedProvider
      readonly property bool isCodex: provider && provider.providerId === "codex"

      Column {
        visible: detail.isCodex
        width: parent.width
        spacing: Style.space(7)

        PanelSectionHeader {
          text: "ACCOUNT"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(detailAccount.implicitHeight, detailPlan.implicitHeight)

          Text {
            id: detailAccount
            anchors.left: parent.left
            anchors.right: detailPlan.left
            anchors.rightMargin: Style.space(12)
            text: detail.provider && detail.provider.accountLabel !== ""
              ? detail.provider.accountLabel
              : "Account unavailable"
            color: detail.provider && detail.provider.accountLabel !== "" ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            id: detailPlan
            anchors.right: parent.right
            text: detail.provider ? detail.provider.planLabel : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      PanelSeparator {
        visible: detail.isCodex && detail.provider.windows.length > 0
        foreground: root.foreground
      }

      Column {
        visible: detail.provider && detail.provider.windows.length > 0
        width: parent.width
        spacing: Style.space(10)

        PanelSectionHeader {
          text: "LIMITS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Repeater {
          model: detail.provider ? detail.provider.windows : []
          LimitRow { required property var modelData; window: modelData }
        }
      }

      Text {
        visible: detail.provider && detail.provider.windows.length === 0
        width: parent.width
        text: "This provider did not return a rate-limit window."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      PanelSeparator {
        visible: detail.provider && (detail.isCodex || !!detail.provider.credits || !!detail.provider.cost)
        foreground: root.foreground
      }

      Column {
        visible: detail.isCodex
        width: parent.width
        spacing: Style.space(7)

        PanelSectionHeader {
          text: "RESET CREDITS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Item {
          visible: detail.provider && !!detail.provider.resetCredits
          width: parent.width
          implicitHeight: Math.max(detailCreditCount.implicitHeight, detailCreditExpiry.implicitHeight)

          Text {
            id: detailCreditCount
            anchors.left: parent.left
            text: detail.provider && detail.provider.resetCredits
              ? Math.round(detail.provider.resetCredits.availableCount) + " available"
              : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            id: detailCreditExpiry
            anchors.left: detailCreditCount.right
            anchors.right: parent.right
            anchors.leftMargin: Style.space(12)
            text: detail.provider && detail.provider.resetCredits
              && detail.provider.resetCredits.expiresAt !== ""
              ? Model.expiryLabel(detail.provider.resetCredits.expiresAt, root.nowMs)
              : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
          }
        }

        Text {
          visible: detail.provider && !detail.provider.resetCredits
          width: parent.width
          text: "Reset-credit data is unavailable."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }

      PanelSeparator {
        visible: detail.isCodex && detail.provider && (!!detail.provider.credits || !!detail.provider.cost)
        foreground: root.foreground
      }

      Column {
        visible: detail.provider && !!detail.provider.credits
        width: parent.width
        spacing: Style.space(7)

        PanelSectionHeader {
          text: "CREDITS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          text: detail.provider && detail.provider.credits
            ? Model.formatMoney(detail.provider.credits.remaining) + " remaining"
            : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      PanelSeparator {
        visible: detail.provider && !!detail.provider.credits && !!detail.provider.cost
        foreground: root.foreground
      }

      Column {
        visible: detail.provider && !!detail.provider.cost
        width: parent.width
        spacing: Style.space(7)

        PanelSectionHeader {
          text: "COST"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(costLabel.implicitHeight, providerCost.implicitHeight)
          Text {
            id: costLabel
            anchors.left: parent.left
            text: detail.provider && detail.provider.cost ? detail.provider.cost.summaryLabel : "Current"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            id: providerCost
            anchors.right: parent.right
            text: detail.provider && detail.provider.cost
              ? Model.formatMoney(detail.provider.cost.summaryCostUSD) + " · "
                + Model.formatTokens(detail.provider.cost.summaryTokens) + " tokens"
              : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Item {
          visible: detail.provider && detail.provider.cost && detail.provider.cost.last30DaysCostUSD !== null
          width: parent.width
          implicitHeight: Math.max(monthLabel.implicitHeight, monthCost.implicitHeight)
          Text {
            id: monthLabel
            anchors.left: parent.left
            text: "Last 30 days"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            id: monthCost
            anchors.right: parent.right
            text: detail.provider && detail.provider.cost
              ? Model.formatMoney(detail.provider.cost.last30DaysCostUSD) + " · "
                + Model.formatTokens(detail.provider.cost.last30DaysTokens) + " tokens"
              : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          visible: detail.provider && detail.provider.cost && detail.provider.cost.daily.length > 0
          width: parent.width
          spacing: Style.space(5)

          PanelSectionHeader {
            text: "DAILY HISTORY"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          DailyCostChart {
            width: parent.width
            days: detail.provider && detail.provider.cost ? detail.provider.cost.daily : []
          }
        }
      }

      Text {
        visible: service.costError !== ""
        width: parent.width
        text: service.costError
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
