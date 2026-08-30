/*
THESIS: Default Overview ranks real providers by the quota most likely to block the next prompt; it refuses static tabs and provider-first opening.
OWN-WORLD: Omarchy theme tokens, flat popup surfaces, fine dividers, compact mono typography, restrained accent, and urgent color only for risk.
STORY: See service health, scan the constraint queue, then open one provider for every available limit and cost fact.
FIRST VIEWPORT: A 380×640 tray panel places dynamic tabs first, a compact status hero second, ranked quota rows in the center, and freshness/cost/refresh at the foot.
FORM: Constraint Queue, structure 7, seed 2cdaad50.
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
  property string selectedViewId: "overview"
  property int queueCursor: 0
  property bool cursorActive: false
  property double nowMs: Date.now()

  readonly property var selectedProvider: providerForId(selectedViewId)
  readonly property bool alarming: providers.length > 0 && providers[0].bindingWindow
    && providers[0].bindingWindow.usedPercent >= 90
  readonly property bool failed: service.status === "error"
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

  function selectedTabIndex() {
    if (selectedViewId === "overview") return 0
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === selectedViewId) return i + 1
    return 0
  }

  function selectTab(index) {
    var count = providers.length + 1
    if (count <= 0) return
    var wrapped = ((index % count) + count) % count
    selectedViewId = wrapped === 0 ? "overview" : providers[wrapped - 1].providerId
    queueCursor = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  function openProvider(providerId) {
    if (!providerForId(providerId)) return
    selectedViewId = providerId
    queueCursor = 0
    if (panelFlick) panelFlick.contentY = 0
  }

  function secondaryWindow(provider) {
    return provider && provider.windows && provider.windows.length > 1 ? provider.windows[1] : null
  }

  function statusLabel() {
    if (service.status === "stopped") return "SERVICE STOPPED"
    if (service.status === "starting") return "CONNECTING"
    if (service.status === "error") return providers.length > 0 ? "SHOWING LAST DATA" : "CONNECTION FAILED"
    if (service.refreshing) return "REFRESHING"
    if (alarming) return "LIMIT ATTENTION"
    if (providers.length === 0) return "NO ACTIVE PROVIDERS"
    return providers.length + (providers.length === 1 ? " PROVIDER READY" : " PROVIDERS READY")
  }

  function statusColor() {
    if (failed || alarming) return urgent
    if (service.status === "ready") return foreground
    return dim
  }

  function statusHelp() {
    if (service.status === "starting") return "Waiting for the local CodexBar service…"
    if (service.status === "error") return service.lastError || "CodexBar is unavailable. Retry when the service is ready."
    if (providers.length === 0) return "CodexBar returned no usable provider records yet. Use a provider, then refresh."
    return ""
  }

  function latestUpdatedLabel() {
    return Model.updatedLabel(service.lastUpdatedAt, nowMs)
  }

  function ensureSelection() {
    if (selectedViewId !== "overview" && !providerForId(selectedViewId)) selectedViewId = "overview"
    queueCursor = clamp(queueCursor, 0, Math.max(0, providers.length - 1))
  }

  function moveVertical(delta) {
    cursorActive = true
    if (selectedViewId === "overview" && providers.length > 0) {
      queueCursor = clamp(queueCursor + delta, 0, providers.length - 1)
      return
    }
    panelFlick.contentY = clamp(panelFlick.contentY + delta * Style.space(56), 0,
      Math.max(0, panelFlick.contentHeight - panelFlick.height))
  }

  function activateCursor() {
    if (selectedViewId === "overview" && providers.length > 0) openProvider(providers[queueCursor].providerId)
    else service.refreshNow()
  }

  onProvidersChanged: ensureSelection()
  onOpenedChanged: if (opened) {
    selectedViewId = "overview"
    queueCursor = 0
    cursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    service.refreshNow()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  CodexBarService {
    id: service
    settings: root.settings
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
    function refresh(): string { service.refreshNow(); return "ok" }
    function overview(): string { root.selectedViewId = "overview"; return "ok" }
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
    contentHeight: panel.fittedContentHeight(
      Math.max(contentColumn.implicitHeight, Style.space(640)), Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.selectTab(root.selectedTabIndex() + dx)
        }
        if (dy !== 0) root.moveVertical(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") service.refreshNow()
        if (text === "o" || text === "O") root.selectedViewId = "overview"
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
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
              width: Math.max(tabsFlick.width, (root.providers.length + 1) * Style.space(84))
              implicitHeight: Style.space(34)
              color: "transparent"
              borderSpec: Border.flat(root.alpha(root.foreground, 0.32), 1)
              radius: Style.cornerRadius

              Row {
                anchors.fill: parent

                TabSegment {
                  label: "Overview"
                  providerId: "overview"
                  tabIndex: 0
                  width: tabsTrack.width / Math.max(1, root.providers.length + 1)
                }

                Repeater {
                  model: root.providers

                  TabSegment {
                    required property var modelData
                    required property int index
                    label: modelData.providerName
                    providerId: modelData.providerId
                    tabIndex: index + 1
                    width: tabsTrack.width / Math.max(1, root.providers.length + 1)
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

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
                text: root.selectedViewId === "overview" ? "CodexBar" : (root.selectedProvider ? root.selectedProvider.providerName : "CodexBar")
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
                  : (root.selectedProvider && root.selectedProvider.source ? root.selectedProvider.source : "Provider usage")
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
            color: root.failed ? root.alpha(root.urgent, 0.10) : root.alpha(root.foreground, 0.05)
            borderSpec: Border.flat(root.failed ? root.alpha(root.urgent, 0.35) : root.alpha(root.foreground, 0.18), 1)
            radius: Style.cornerRadius

            Text {
              id: statusMessage
              anchors.left: parent.left
              anchors.right: retryButton.visible ? retryButton.left : parent.right
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: root.statusHelp()
              color: root.failed ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              id: retryButton
              visible: root.failed || service.status === "stopped"
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
              onClicked: service.probe()
            }
          }

          Loader {
            width: parent.width
            sourceComponent: root.selectedViewId === "overview" ? overviewContent : providerContent
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

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
                  text: "COST"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }
                Text {
                  id: costValue
                  width: parent.width
                  text: root.footerCost
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
              text: service.refreshing ? "Refreshing usage…" : "Refresh usage"
              iconText: service.refreshing ? "󰑐" : ""
              iconSpinning: service.refreshing
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              enabled: !service.refreshing
              opacity: enabled ? 1 : 0.55
              onClicked: service.refreshNow()
            }
          }
        }
      }
    }
  }

  component UsageMeter: Item {
    id: meter
    property real value: 0
    property bool alarming: false
    property real thickness: Math.max(Style.space(5), Math.round(Style.spacing.controlHeight * 0.16))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * root.clamp(meter.value / 100, 0, 1)
        radius: parent.radius
        color: meter.alarming ? root.urgent : root.foreground

        Behavior on width {
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
      onEntered: root.cursorActive = true
      onClicked: root.selectTab(tabSegment.tabIndex)
    }
  }

  component QueueRow: CursorSurface {
    id: queueRow
    property var provider: null
    property int rowIndex: 0

    readonly property var headline: provider ? provider.bindingWindow : null
    readonly property var secondary: root.secondaryWindow(provider)
    readonly property bool limitAlarming: headline && headline.usedPercent >= 90

    implicitHeight: queueContent.implicitHeight + Style.space(18)
    radius: Style.cornerRadius
    foreground: root.foreground
    accent: root.accent
    hasCursor: root.cursorActive && root.selectedViewId === "overview" && root.queueCursor === rowIndex

    Column {
      id: queueContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(7)

      Text {
        width: parent.width
        text: queueRow.provider ? queueRow.provider.providerName.toUpperCase() : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(providerUsed.implicitHeight, providerLeft.implicitHeight)

        Text {
          id: providerUsed
          anchors.left: parent.left
          anchors.right: providerLeft.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: queueRow.headline ? Model.formatPercent(queueRow.headline.usedPercent) + " USED" : "LIMIT NOT REPORTED"
          color: queueRow.limitAlarming ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          id: providerLeft
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: queueRow.headline ? Model.formatPercent(queueRow.headline.remainingPercent) + " LEFT" : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }

      UsageMeter {
        visible: !!queueRow.headline
        width: parent.width
        value: queueRow.headline ? queueRow.headline.usedPercent : 0
        alarming: queueRow.limitAlarming
      }

      Item {
        visible: !!queueRow.headline
        width: parent.width
        implicitHeight: Math.max(windowTitle.implicitHeight, windowReset.implicitHeight)

        Text {
          id: windowTitle
          anchors.left: parent.left
          anchors.right: windowReset.left
          anchors.rightMargin: Style.space(8)
          text: queueRow.headline ? queueRow.headline.title.toUpperCase() : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
        Text {
          id: windowReset
          anchors.right: parent.right
          text: queueRow.headline ? Model.resetLabel(queueRow.headline, root.nowMs).toUpperCase() : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        visible: !!queueRow.secondary
        width: parent.width
        text: queueRow.secondary
          ? queueRow.secondary.title.toUpperCase() + " " + Model.formatPercent(queueRow.secondary.usedPercent)
            + " USED · " + Model.formatPercent(queueRow.secondary.remainingPercent) + " LEFT · "
            + Model.resetLabel(queueRow.secondary, root.nowMs).toUpperCase()
          : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.queueCursor = queueRow.rowIndex
      }
      onClicked: if (queueRow.provider) root.openProvider(queueRow.provider.providerId)
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
        text: limitRow.window ? Model.formatPercent(limitRow.window.usedPercent) + " used" : ""
        color: limitRow.limitAlarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    UsageMeter {
      width: parent.width
      value: limitRow.window ? limitRow.window.usedPercent : 0
      alarming: limitRow.limitAlarming
    }

    Text {
      width: parent.width
      text: limitRow.window
        ? Model.formatPercent(limitRow.window.remainingPercent) + " left · " + Model.resetLabel(limitRow.window, root.nowMs)
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

  Component {
    id: overviewContent

    Column {
      width: parent ? parent.width : 0
      spacing: Style.space(8)

      PanelSectionHeader {
        visible: root.providers.length > 0
        text: "MOST CONSTRAINED"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.providers

        Column {
          required property var modelData
          required property int index
          width: parent.width
          spacing: Style.space(8)

          QueueRow {
            width: parent.width
            provider: modelData
            rowIndex: index
          }

          PanelSeparator {
            visible: index < root.providers.length - 1
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
        visible: detail.provider && (!!detail.provider.credits || !!detail.provider.cost)
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
