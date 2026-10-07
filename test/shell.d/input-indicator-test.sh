#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

OMARCHY_PATH="$ROOT" /usr/bin/python - <<'PY'
import importlib.util
import os
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("indicator", os.environ["OMARCHY_PATH"] + "/default/input-methods/indicator.py")
indicator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(indicator)

with patch.object(indicator, "call", side_effect=[
  ("Default",),
  ("us", [("keyboard-us", ""), ("mozc", ""), ("mozc", "")]),
  ("mozc", "Mozc", "", "fcitx_mozc", "あ", "ja", "mozc", True, "", {}),
]):
  state = indicator.snapshot(None)
  assert state == {"methods": ["keyboard-us", "mozc"], "current": "mozc", "name": "Mozc", "label": "あ", "language": "ja"}
print("ok - live state deduplicates modes and reads language independently of the engine label")

def check_cycle(current, methods, expected):
  state = {"current": current, "methods": methods}
  with patch.object(indicator, "snapshot", return_value=state), patch.object(indicator, "call") as call:
    indicator.cycle(None)
    if expected is None:
      call.assert_not_called()
    else:
      assert call.call_args.args[1] == "SetCurrentIM"
      assert call.call_args.args[2].unpack() == (expected,)

check_cycle("keyboard-us", ["keyboard-us", "mozc"], "mozc")
check_cycle("mozc", ["keyboard-us", "mozc"], "keyboard-us")
check_cycle("mozc", ["keyboard-us", "mozc", "hangul"], "hangul")
check_cycle("hangul", ["keyboard-us", "mozc", "hangul"], "keyboard-us")
check_cycle("keyboard-us", ["keyboard-us"], None)
check_cycle("removed", ["keyboard-us", "mozc"], None)
check_cycle("", [], None)
print("ok - input cycling covers Latin, multiple engines, single modes, and stale contexts")

entries = [("keyboard-us", "English", "", "input-keyboard", "en", "en", True),
           ("pinyin", "Pinyin", "", "fcitx-pinyin", "拼", "zh_CN", True)]
live = {"methods": ["keyboard-us", "pinyin"], "current": "", "name": "", "label": "", "language": ""}
selected = []
def fake_call(bus, method, args=None):
  if method == "AvailableInputMethods":
    return (entries,)
  if method == "SetCurrentIM":
    selected.append(args.unpack()[0])
    live["current"] = selected[-1]
    return ()
  raise AssertionError(method)

with patch.object(indicator, "snapshot", side_effect=lambda bus: dict(live)), patch.object(indicator, "call", side_effect=fake_call):
  reader = indicator.Indicator(None)
  assert reader.refresh()["current"] == "keyboard-us"
  reader.select_next()
  assert reader.refresh()["current"] == "pinyin"
  assert reader.pending == "pinyin" and selected == []
  reader.select_next()
  assert reader.pending == "keyboard-us"
  reader.select_next()
  live["current"] = "keyboard-us"
  assert reader.refresh()["current"] == "pinyin"
  assert reader.pending == "" and selected == ["pinyin"]
  live["current"] = ""
  reader.select_next()
  live["methods"] = ["pinyin"]
  reader.refresh()
  assert reader.pending == ""
print("ok - desktop clicks update the label, cycle pending choices, and apply once a text context exists")
PY
