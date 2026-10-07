import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

Item {
  id: root
  property var shell: null
  property string monitorName: ""
  property string zone: "none"
  property real targetX: 0
  property real targetY: 0
  property real targetWidth: 0
  property real targetHeight: 0
  property var targetScreen: null

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "omarchy_snap_preview") return
      var parts = event.data.split(",")
      if (parts.length < 6 || parts[1] === "none") {
        root.zone = "none"
        return
      }
      var screens = Quickshell.screens
      root.targetScreen = null
      for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === parts[0]) root.targetScreen = screens[i]
      }
      if (!root.targetScreen) return
      root.targetX = Number(parts[2]) - root.targetScreen.x
      root.targetY = Number(parts[3]) - root.targetScreen.y
      root.targetWidth = Number(parts[4])
      root.targetHeight = Number(parts[5])
      root.zone = parts[1]
    }
  }

  PanelWindow {
    visible: root.zone !== "none" && root.targetScreen !== null
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-floating-snap"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
      x: root.targetX
      y: root.targetY
      width: root.targetWidth
      height: root.targetHeight
      color: Util.alpha(Color.accent, 0.13)
      border.color: Util.alpha(Color.accent, 0.8)
      border.width: 2
      radius: Style.cornerRadius

      Rectangle {
        anchors.centerIn: parent
        width: label.implicitWidth + Style.space(32)
        height: label.implicitHeight + Style.space(20)
        color: Color.popups.background
        border.color: Color.accent
        border.width: 1
        radius: Style.cornerRadius
        Text {
          id: label
          anchors.centerIn: parent
          text: root.zone === "maximize" ? "Release to maximize" : "Release for half screen"
          textFormat: Text.PlainText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.baseSize
        }
      }
    }
  }
}
