function parseStatus(raw) {
  var value
  try { value = JSON.parse(String(raw || "")) } catch (error) { return null }
  if (!value || typeof value.enabled !== "boolean" || !Array.isArray(value.windows)) return null

  var seen = {}
  var windows = []
  value.windows.forEach(function(window) {
    if (!window || !/^0x[0-9a-f]+$/i.test(String(window.address || ""))) return
    var address = String(window.address).toLowerCase()
    if (seen[address]) return
    seen[address] = true
    var appClass = String(window.class || "").trim()
    windows.push({
      address: address,
      title: String(window.title || "").trim() || appClass || "Window",
      class: appClass,
      workspace: String(window.workspace || "").trim(),
      monitor: String(window.monitor || "").trim()
    })
  })
  return {
    enabled: value.enabled,
    available: typeof value.available === "boolean" ? value.available : value.enabled,
    allWorkspaces: value.allWorkspaces === true,
    overrides: Math.max(0, Number(value.overrides) || 0),
    layout: value.layout || (value.enabled ? "floating" : "dwindle"),
    workspace: String(value.workspace || ""),
    windows: windows
  }
}

// Keep the keyboard cursor on the same window when a new one is shelved,
// and keep the mode control selected when the number of windows changes.
function selectionAfterRefresh(previous, next, index, selectFirst) {
  if (selectFirst) return 0
  if (index >= previous.length) return next.length + Math.min(1, index - previous.length)
  var selected = previous[index]
  if (selected) {
    for (var i = 0; i < next.length; i++) {
      if (next[i].address === selected.address) return i
    }
  }
  return Math.max(0, Math.min(index, next.length))
}

function moveSelection(index, direction, windowCount) {
  var count = windowCount + 2
  return ((index + direction) % count + count) % count
}

function workspaceLabel(window) {
  var workspace = String((window && window.workspace) || "")
  return workspace ? "From workspace " + workspace : "Set aside"
}

function layoutLabel(layout) {
  return { dwindle: "Tiling", scrolling: "Scrolling", floating: "Floating" }[layout] || "Tiling"
}

function nextLayoutLabel(layout) {
  return { dwindle: "Scrolling", scrolling: "Floating", floating: "Tiling" }[layout] || "Tiling"
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    selectionAfterRefresh: selectionAfterRefresh,
    moveSelection: moveSelection,
    workspaceLabel: workspaceLabel,
    layoutLabel: layoutLabel,
    nextLayoutLabel: nextLayoutLabel
  }
}
