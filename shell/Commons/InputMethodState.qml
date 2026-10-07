pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property var state: ({})

  function cycle() {
    if (watcher.running) watcher.write("cycle\n")
  }

  // One reader and pending selection for every monitor's keyboard widget.
  Process {
    id: watcher
    command: ["/usr/bin/python", Quickshell.env("OMARCHY_PATH") + "/default/input-methods/indicator.py"]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      onRead: data => {
        try { root.state = JSON.parse(data) } catch (e) {}
      }
    }
    onExited: {
      root.state = ({})
      restart.restart()
    }
  }

  Timer {
    id: restart
    interval: 5000
    onTriggered: watcher.running = true
  }
}
