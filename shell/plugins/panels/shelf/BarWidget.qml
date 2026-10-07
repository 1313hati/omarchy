import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "omarchy.shelf"

  readonly property bool modeEnabled: panelLoader.item ? panelLoader.item.modeEnabled : false
  readonly property bool modeAvailable: panelLoader.item ? panelLoader.item.modeAvailable : false
  readonly property string layoutLabel: panelLoader.item ? Model.layoutLabel(panelLoader.item.currentLayout) : "Tiling"
  readonly property int windowCount: panelLoader.item ? panelLoader.item.windows.length : 0
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
  readonly property string shelfIcon: "\udb84\ude94"

  function injectPanel() {
    var panel = panelLoader.item
    if (!panel) return
    panel.bar = root.bar
    panel.settings = root.settings
    panel.anchorItem = button
    panel.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  visible: modeAvailable || windowCount > 0 || opened
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  ShellIpc {
    target: "omarchy.shelf"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.broadcast("refresh") }
  }

  WidgetButton {
    id: button
    bar: root.bar
    anchors.fill: parent
    horizontalMargin: 10
    foreground: root.modeEnabled ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
    text: root.vertical
      ? root.shelfIcon + (root.windowCount ? "\n" + root.windowCount : "")
      : root.shelfIcon + "  " + root.layoutLabel + (root.windowCount ? "  · " + root.windowCount : "")
    tooltipText: root.windowCount
      ? "Shelf · " + root.windowCount + (root.windowCount === 1 ? " window set aside" : " windows set aside")
      : root.layoutLabel + " · Workspace layout and window Shelf"
    onPressed: root.togglePanel()
  }

}
