#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

run_node_test <<'JS'
const shelf = requireFromRoot('shell/plugins/panels/shelf/Model.js')

const terminal = { address: '0xab', title: '<notes> & tasks', class: 'foot', workspace: '2', monitor: 'DP-1' }
const browser = { address: '0xcd', title: 'Browser', class: 'chromium', workspace: '1', monitor: 'DP-1' }
const editor = { address: '0xef', title: 'Editor', class: 'code', workspace: '3', monitor: 'DP-2' }

assertDeepEqual(
  shelf.parseStatus(JSON.stringify({ enabled: true, windows: [terminal, browser] })),
  { enabled: true, available: true, allWorkspaces: false, overrides: 0, layout: 'floating', workspace: '', windows: [terminal, browser] },
  'shelf preserves minimize order, workspace, and literal window titles'
)
assertEqual(shelf.parseStatus(''), null, 'shelf ignores an interrupted status response')
assertEqual(shelf.parseStatus('{"enabled":false}'), null, 'shelf rejects incomplete state instead of losing minimized windows')
assertDeepEqual(
  shelf.parseStatus(JSON.stringify({ enabled: false, windows: [terminal, null, { address: 'bad' }, terminal, { address: '0xEF', class: 'code' }] })),
  { enabled: false, available: false, allWorkspaces: false, overrides: 0, layout: 'dwindle', workspace: '', windows: [terminal, { address: '0xef', title: 'code', class: 'code', workspace: '', monitor: '' }] },
  'shelf removes duplicate and invalid windows while keeping recoverable entries'
)

assertEqual(shelf.selectionAfterRefresh([terminal, browser], [editor, terminal, browser], 1), 2, 'newly minimized windows do not move the keyboard cursor to another app')
assertEqual(shelf.selectionAfterRefresh([terminal, browser], [browser], 0), 0, 'closing the selected window selects the next available window')
assertEqual(shelf.selectionAfterRefresh([terminal, browser], [terminal], 1), 1, 'closing the last row leaves a valid mode-control selection')
assertEqual(shelf.selectionAfterRefresh([terminal], [editor, terminal], 1), 2, 'mode control remains selected when the shelf grows')
assertEqual(shelf.selectionAfterRefresh([], [terminal, browser], 0, true), 0, 'opening before initial status selects the first window instead of the mode control')
assertEqual(shelf.selectionAfterRefresh([terminal], [terminal], 1, true), 0, 'reopening with unchanged status resets the cursor to the first window')
assertEqual(shelf.selectionAfterRefresh([], [], 0, true), 0, 'opening an empty shelf keeps the mode control reachable')
assertEqual(shelf.moveSelection(0, -1, 2), 3, 'up from the first window reaches the global mode control')
assertEqual(shelf.moveSelection(3, 1, 2), 0, 'down from the global mode control reaches the first window')
assertEqual(shelf.moveSelection(0, 1, 0), 1, 'an empty shelf still allows choosing local layout or global default')
assertEqual(shelf.workspaceLabel(terminal), 'From workspace 2', 'shelf rows describe where a window was minimized')
assertEqual(shelf.workspaceLabel({}), 'Set aside', 'recovered windows do not invent an origin workspace')
assertEqual(shelf.selectionAfterRefresh([terminal], [terminal, browser], 2), 3, 'global toggle selection survives a newly minimized window')
const mixed = shelf.parseStatus(JSON.stringify({ enabled: false, available: true, allWorkspaces: true, overrides: 1, layout: 'scrolling', workspace: '4', windows: [terminal] }))
assertEqual(mixed.allWorkspaces, true, 'the global default is independent of the current workspace layout')
assertEqual(mixed.layout, 'scrolling', 'the shelf reports the destination layout')
assertEqual(shelf.layoutLabel('dwindle'), 'Tiling', 'workspace layout uses its familiar name')
assertEqual(shelf.nextLayoutLabel('dwindle'), 'Scrolling', 'tiling cycles to scrolling')
assertEqual(shelf.nextLayoutLabel('scrolling'), 'Floating', 'scrolling cycles to floating')
assertEqual(shelf.nextLayoutLabel('floating'), 'Tiling', 'floating cycles back to tiling')
JS
