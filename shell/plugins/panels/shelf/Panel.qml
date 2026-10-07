import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omarchy.shelf"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property bool modeEnabled: false
  property bool modeAvailable: false
  property bool allWorkspaces: false
  property int workspaceOverrides: 0
  property string currentLayout: "dwindle"
  property string currentWorkspace: ""
  property var windows: []
  property int selectedIndex: 0
  property bool selectFirstAfterOpen: false
  property bool refreshPending: false
  property string stateSignature: ""
  property string errorMessage: ""
  property string pendingAction: ""
  property string queuedRestoreAddress: ""
  readonly property bool actionBusy: actionProc.running || queuedRestoreAddress !== ""

  function open() {
    if (queuedRestoreAddress !== "") return
    selectedIndex = 0
    selectFirstAfterOpen = true
    pointerGate.reset()
    errorMessage = ""
    root.controller.show()
    refresh()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (statusProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    statusProc.running = true
  }

  function applyStatus(raw) {
    var next = Model.parseStatus(raw)
    if (!next) return
    var signature = JSON.stringify(next)
    // Opening can precede the first status result. Index zero in that empty
    // model must become the first window, not a preserved mode-control cursor.
    selectedIndex = Model.selectionAfterRefresh(windows, next.windows, selectedIndex, selectFirstAfterOpen)
    selectFirstAfterOpen = false
    if (signature === stateSignature) return
    pointerGate.reset()
    modeEnabled = next.enabled
    modeAvailable = next.available
    allWorkspaces = next.allWorkspaces
    workspaceOverrides = next.overrides
    currentLayout = next.layout
    currentWorkspace = next.workspace
    windows = next.windows
    stateSignature = signature
  }

  function act(action, address) {
    if (actionBusy) return
    errorMessage = ""
    pendingAction = action
    if (action === "restore") {
      queuedRestoreAddress = address
      root.close()
      restoreAfterUnmap()
    } else {
      actionProc.command = action === "cycle"
        ? ["omarchy-hyprland-workspace-layout-toggle"]
        : ["omarchy-toggle-floating-workspaces"]
      actionProc.running = true
    }
  }

  function restoreAfterUnmap() {
    if (queuedRestoreAddress === "" || panel.backingWindowVisible) return
    // Closing the controller starts the fade. The compositor restores the
    // previous focus only when the layer surface actually unmaps, so wait for
    // that lifecycle transition before focusing the window from the Shelf.
    var address = queuedRestoreAddress
    queuedRestoreAddress = ""
    actionProc.command = ["omarchy-hyprland-window-restore", address]
    actionProc.running = true
  }

  function moveCursor(direction) {
    pointerGate.reset()
    selectedIndex = Model.moveSelection(selectedIndex, direction, windows.length)
    revealCursor()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse) || selectFirstAfterOpen) return
    selectedIndex = index
  }

  function revealCursor() {
    var item = selectedIndex < windows.length ? windowRepeater.itemAt(selectedIndex) : selectedIndex === windows.length ? workspaceMode : modeToggle
    if (!item) return
    var position = item.mapToItem(shelfColumn, 0, 0)
    if (position.y < shelfScroll.contentY) shelfScroll.contentY = position.y
    else if (position.y + item.height > shelfScroll.contentY + shelfScroll.height)
      shelfScroll.contentY = position.y + item.height - shelfScroll.height
  }

  function activateCursor() {
    if (selectFirstAfterOpen) return
    if (selectedIndex < windows.length) act("restore", windows[selectedIndex].address)
    else act(selectedIndex === windows.length ? "cycle" : "toggle")
  }

  function applicationEntry(window) {
    return window.class ? DesktopEntries.heuristicLookup(window.class) : null
  }

  function iconSource(window) {
    var entry = applicationEntry(window)
    var icon = entry ? String(entry.icon || "") : ""
    if (icon.charAt(0) === "/") return Util.fileUrl(icon)
    return Quickshell.iconPath(icon || window.class.toLowerCase(), true)
  }

  function appLabel(window) {
    var entry = applicationEntry(window)
    return entry && entry.name ? entry.name : ""
  }

  Process {
    id: statusProc
    command: ["omarchy-hyprland-window-shelf-list"]
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(text)
    }
    onRunningChanged: {
      if (!running && root.refreshPending) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: actionProc
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.controller.show()
        root.errorMessage = root.pendingAction === "restore"
          ? "Couldn't restore this window. Try again."
          : "Couldn't change the window mode. Try again."
      }
      refreshTimer.restart()
    }
  }

  Timer {
    id: refreshTimer
    interval: 90
    onTriggered: root.refresh()
  }

  Timer {
    interval: 1500
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2", "workspace", "workspacev2", "configreloaded"].indexOf(String(event.name)) !== -1)
        refreshTimer.restart()
    }
  }

  Connections {
    target: panel
    function onBackingWindowVisibleChanged() {
      root.restoreAfterUnmap()
    }
  }

  Component.onCompleted: refresh()

  PointerMoveGate {
    id: pointerGate
    referenceItem: keyCatcher
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(390))
    contentHeight: fittedContentHeight(shelfColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy) root.moveCursor(dy) }
      onTabRequested: function(direction) { root.moveCursor(direction) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()

      Flickable {
        id: shelfScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: shelfColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: shelfColumn
          width: shelfScroll.width
          spacing: Style.spacing.panelGap

          Column {
            width: parent.width
            spacing: Style.spacing.sm

            Row {
              width: parent.width
              spacing: Style.spacing.controlGap

              Text {
                id: shelfTitle
                text: "Shelf"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                visible: root.windows.length > 0
                anchors.baseline: shelfTitle.baseline
                text: root.windows.length
                textFormat: Text.PlainText
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }

            Text {
              width: parent.width
              text: "Set a window aside. Restore it to this workspace."
              color: Util.alpha(Color.popups.text, 0.65)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: Color.popups.text }

          Column {
            width: parent.width
            spacing: Style.spacing.sm
            visible: root.windows.length > 0

            Repeater {
              id: windowRepeater
              model: root.windows

              CursorSurface {
                id: windowRow
                required property var modelData
                required property int index
                width: parent.width
                height: Math.max(Style.space(62), windowLabels.implicitHeight + Style.spacing.lg * 2)
                hasCursor: root.selectedIndex === index
                foreground: Color.popups.text

                Item {
                  id: iconBox
                  width: Style.space(30)
                  height: width
                  anchors.left: parent.left
                  anchors.leftMargin: Style.spacing.lg
                  anchors.verticalCenter: parent.verticalCenter

                  Image {
                    id: appIcon
                    anchors.fill: parent
                    source: root.iconSource(windowRow.modelData)
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                  }

                  Text {
                    visible: !appIcon.visible
                    anchors.centerIn: parent
                    text: "\udb81\ude14"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(24)
                    color: Color.accent
                  }
                }

                Column {
                  id: windowLabels
                  anchors.left: iconBox.right
                  anchors.leftMargin: Style.spacing.xl
                  anchors.right: restoreGlyph.left
                  anchors.rightMargin: Style.spacing.lg
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.sm

                  Text {
                    width: parent.width
                    text: windowRow.modelData.title
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: Color.popups.text
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: (root.appLabel(windowRow.modelData) ? root.appLabel(windowRow.modelData) + " · " : "") + Model.workspaceLabel(windowRow.modelData)
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.6)
                    elide: Text.ElideRight
                  }
                }

                Text {
                  id: restoreGlyph
                  anchors.right: parent.right
                  anchors.rightMargin: Style.spacing.xl
                  anchors.verticalCenter: parent.verticalCenter
                  text: "↗"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  color: Color.accent
                  opacity: windowRow.hasCursor ? 1 : 0.35
                }

                MouseArea {
                  id: windowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.selectFromPointer(windowRow.index, windowRow, { x: mouseX, y: mouseY })
                  onPositionChanged: function(mouse) { root.selectFromPointer(windowRow.index, windowRow, mouse) }
                  onClicked: root.act("restore", windowRow.modelData.address)
                }
              }
            }
          }

          Column {
            width: parent.width
            visible: root.windows.length === 0
            spacing: Style.spacing.lg
            topPadding: Style.spacing.lg
            bottomPadding: Style.spacing.lg

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\udb84\ude94"
              color: Util.alpha(Color.accent, 0.75)
              font.family: Style.font.family
              font.pixelSize: Style.space(30)
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "Nothing set aside"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "Click − on a titlebar or press Super + M.\nYour window will be waiting here."
              color: Util.alpha(Color.popups.text, 0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }

          Text {
            visible: root.errorMessage !== ""
            width: parent.width
            text: root.errorMessage
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: Color.popups.text }

          CursorSurface {
            id: workspaceMode
            width: parent.width
            height: workspaceLabels.implicitHeight + Style.spacing.lg * 2
            foreground: Color.popups.text
            hasCursor: root.selectedIndex === root.windows.length

            Column {
              id: workspaceLabels
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.spacing.lg
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.sm

              Text {
                width: parent.width
                text: "Workspace " + root.currentWorkspace + " · " + Model.layoutLabel(root.currentLayout)
                textFormat: Text.PlainText
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
              Text {
                text: "Super + L · Next: " + Model.nextLayoutLabel(root.currentLayout)
                textFormat: Text.PlainText
                color: Util.alpha(Color.popups.text, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectFromPointer(root.windows.length, workspaceMode, { x: mouseX, y: mouseY })
              onPositionChanged: function(mouse) { root.selectFromPointer(root.windows.length, workspaceMode, mouse) }
              onClicked: root.act("cycle")
            }
          }

          Toggle {
            id: modeToggle
            width: parent.width
            label: "Float all workspaces"
            description: root.allWorkspaces && root.workspaceOverrides
              ? root.workspaceOverrides + (root.workspaceOverrides === 1 ? " workspace uses its own layout." : " workspaces use their own layouts.")
              : "Set the default. Super + L can override it here."
            checked: root.allWorkspaces
            foreground: Color.popups.text
            hasCursor: root.selectedIndex === root.windows.length + 1
            enabled: !root.actionBusy
            onClicked: root.act("toggle")

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectFromPointer(root.windows.length + 1, modeToggle, { x: mouseX, y: mouseY })
              onPositionChanged: function(mouse) { root.selectFromPointer(root.windows.length + 1, modeToggle, mouse) }
              onClicked: modeToggle.clicked()
            }
          }

          Text {
            width: parent.width
            text: "↑ ↓ choose    Enter " + (root.selectedIndex < root.windows.length ? "restore" : root.selectedIndex === root.windows.length ? "cycle" : "toggle") + "    Esc close"
            textFormat: Text.PlainText
            color: Util.alpha(Color.popups.text, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
