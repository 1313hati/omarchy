#!/bin/bash

# VM-only: exercises the shared setup command and real composition for every
# shipped engine. Restore the profile, shortcut settings, and font preference.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

selection=$(omarchy-input-method status)
initial_method=$(jq -r .installed_method <<< "$selection")
initial_layout=$(jq -r .layout <<< "$selection")
group=$(fcitx5-remote -q)
initial_info=$(busctl --user --json=short call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 InputMethodGroupInfo s "$group")
jq -e --arg layout "$initial_layout" '.data[0] == $layout' <<< "$initial_info" >/dev/null ||
  fail "installed keyboard layout reaches Fcitx"
if [[ $initial_method != "none" ]]; then
  jq -e --arg method "$initial_method" '.data[1] | any(.[0] == $method)' <<< "$initial_info" >/dev/null ||
    fail "installer-selected engine is ready before live setup"
fi
pass "installer input selection reaches the first desktop session"

work=$(mktemp -d)
dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" > "$ARTIFACTS/input-method-notifications.log" 2>&1 &
notification_monitor=$!
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
paths=("$config_home/fcitx5" "$config_home/fontconfig/conf.d/50-omarchy-input-method.conf" "$data_home/dbus-1/services/org.fcitx.Fcitx5.service")
for (( i = 0; i < ${#paths[@]}; i++ )); do
  if [[ -e ${paths[i]} || -L ${paths[i]} ]]; then
    cp -a "${paths[i]}" "$work/backup-$i"
  fi
done

cleanup() {
  kill "$notification_monitor" 2>/dev/null || true
  wait "$notification_monitor" 2>/dev/null || true
  close_windows '^org\.omarchy\.ime-test$'
  close_windows '^org\.omarchy\.ime-test-gtk$|^org\.qt-project\.qml$|^chrome-.*_omarchy-ime-entry\.html-Default$'
  systemctl --user stop omarchy-fcitx5.service
  for (( i = 0; i < ${#paths[@]}; i++ )); do
    rm -rf "${paths[i]}"
    if [[ -e $work/backup-$i || -L $work/backup-$i ]]; then
      mkdir -p "$(dirname "${paths[i]}")"
      cp -a "$work/backup-$i" "${paths[i]}"
    fi
  done
  busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null
  systemctl --user start omarchy-fcitx5.service
  rm -rf "$work"
}
trap cleanup EXIT

cat > "$work/reader" <<'SH'
#!/bin/bash
IFS= read -r text
printf '%s' "$text" > "$1"
sleep 1
SH
chmod +x "$work/reader"

cat > "$work/entry.py" <<'PY'
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

app = Gtk.Application(application_id="org.omarchy.ime-test-gtk")
def activate(app):
  window = Gtk.ApplicationWindow(application=app, title="GTK input test")
  window.set_default_size(600, 160)
  entry = Gtk.Entry()
  window.set_child(entry)
  window.present()
  entry.grab_focus()
app.connect("activate", activate)
app.run()
PY

cat > "$work/entry.qml" <<'QML'
import QtQuick
import QtQuick.Controls
ApplicationWindow {
  visible: true
  width: 600
  height: 160
  title: "Qt input test"
  TextField {
    anchors.fill: parent
    focus: true
  }
}
QML

cat > "$work/omarchy-ime-entry.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>Browser input test</title>
<input autofocus style="font-size:32px;width:90%" aria-label="Input test">
HTML

compose() {
  fcitx5-remote -s "$method"
  fcitx5-remote -c
  wtype -M ctrl -M shift -k space -m shift -m ctrl
  case "$method" in
    mozc) wtype "nihongo"; wtype -k space ;;
    hangul) wtype "gksrmf" ;;
    pinyin) wtype "nihao"; wtype -k space ;;
    chewing) wtype "su3cl3" ;;
  esac
  sleep 1
}

verify_text() {
  case "$method" in
    mozc) grep -Fxq "日本語" "$work/result" || fail "$1 commits Japanese" ;;
    hangul) grep -Fxq "한글" "$work/result" || fail "$1 commits Korean" ;;
    *) python -c 'import pathlib,sys; assert any("\u4e00" <= c <= "\u9fff" for c in pathlib.Path(sys.argv[1]).read_text())' "$work/result" || fail "$1 commits Han characters" ;;
  esac
  pass "$1 commits composed text"
}

installed=()
for method in mozc hangul pinyin chewing; do
  omarchy-setup-input "$method" > "$ARTIFACTS/setup-input-$method.log" 2>&1 ||
    fail "$method setup completes" "$(cat "$ARTIFACTS/setup-input-$method.log")"
  group=$(fcitx5-remote -q)
  info=$(busctl --user --json=short call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 InputMethodGroupInfo s "$group")
  installed+=("$method")
  for retained in "${installed[@]}"; do
    jq -e --arg method "$retained" '.data[1] | any(.[0] == $method)' <<< "$info" >/dev/null || fail "$retained is still registered"
  done
  owner_pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s org.fcitx.Fcitx5 | awk '{print $2}')
  unit_pid=$(systemctl --user show omarchy-fcitx5.service --property MainPID --value)
  [[ $owner_pid == "$unit_pid" ]] || fail "Fcitx bus owner is the supervised process"

  launch_app "foot --app-id=org.omarchy.ime-test $work/reader $work/result"
  wait_until "$method test terminal opens" 15 window_present '^org\.omarchy\.ime-test$'
  [[ $(fcitx5-remote) == "1" ]] || fail "$method setup starts in Latin mode"
  compose
  screenshot "success-input-$method-composition"
  wtype -k Return
  sleep 0.3
  wtype -k Return
  wait_until "$method commits text" 15 test -s "$work/result"
  verify_text "$method terminal"
  fcitx5-remote -c
  close_windows '^org\.omarchy\.ime-test$'
  rm -f "$work/result"

  for toolkit in gtk qt browser; do
    case "$toolkit" in
      gtk) command="python $work/entry.py"; class='^org\.omarchy\.ime-test-gtk$' ;;
      qt) command="qml6 $work/entry.qml"; class='^org\.qt-project\.qml$' ;;
      browser) command="chromium --user-data-dir=$work/chromium --no-first-run --app=file://$work/omarchy-ime-entry.html"; class='^chrome-.*_omarchy-ime-entry\.html-Default$' ;;
    esac
    launch_app "uwsm app -- $command"
    wait_until "$method $toolkit opens" 30 window_present "$class"
    sleep 1
    compose
    screenshot "success-input-$method-$toolkit-composition"
    wtype -k Return
    fcitx5-remote -c
    wl-copy --clear
    wtype -M ctrl -k a -k c -m ctrl
    sleep 0.3
    wl-paste --no-newline > "$work/result" || fail "$method $toolkit copies committed text"
    verify_text "$method $toolkit"
    screenshot "success-input-$method-$toolkit-committed"
    close_windows "$class"
    wait_until "$toolkit closes" 15 window_absent "$class"
  done
done

if grep -q 'member=Notify' "$ARTIFACTS/input-method-notifications.log"; then
  fail "input setup and composition produce no additional notifications" "$(cat "$ARTIFACTS/input-method-notifications.log")"
fi
pass "all four input engines remain quiet during setup and composition"
