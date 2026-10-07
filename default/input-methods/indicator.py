"""Live Fcitx state for the existing keyboard layout widget."""

import json
import sys

from gi.repository import Gio, GLib


BUS = "org.fcitx.Fcitx5"
INTERFACE = "org.fcitx.Fcitx.Controller1"


def call(bus, method, args=None):
  # Reading the bar must neither activate a stopped service nor wait indefinitely.
  return bus.call_sync(BUS, "/controller", INTERFACE, method, args, None,
                       Gio.DBusCallFlags.NO_AUTO_START, 1000, None).unpack()


def snapshot(bus):
  group = call(bus, "CurrentInputMethodGroup")[0]
  methods = list(dict.fromkeys(item[0] for item in
                              call(bus, "InputMethodGroupInfo", GLib.Variant("(s)", (group,)))[1]))
  info = call(bus, "CurrentInputMethodInfo")
  return {"methods": methods, "current": info[0], "name": info[1], "label": info[4], "language": info[5]}


def cycle(bus):
  state = snapshot(bus)
  methods = state["methods"]
  if len(methods) > 1 and state["current"] in methods:
    following = methods[(methods.index(state["current"]) + 1) % len(methods)]
    call(bus, "SetCurrentIM", GLib.Variant("(s)", (following,)))


def watch(bus):
  previous = None

  def refresh():
    nonlocal previous
    try:
      state = snapshot(bus)
    except GLib.Error:
      state = {"methods": [], "current": "", "name": "", "language": ""}
    line = json.dumps(state, ensure_ascii=False)
    if line != previous:
      print(line, flush=True)
      previous = line
    return GLib.SOURCE_CONTINUE

  # Fcitx's controller has no current-method-changed signal. Keep one bus
  # connection open instead of spawning a command on every poll. Polling also
  # follows per-application input contexts and recovers after service restarts.
  refresh()
  GLib.timeout_add(500, refresh)
  GLib.MainLoop().run()


if __name__ == "__main__":
  try:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    if sys.argv[1:] == ["cycle"]:
      cycle(bus)
    else:
      watch(bus)
  except GLib.Error as error:
    raise SystemExit(str(error))
