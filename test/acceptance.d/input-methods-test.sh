#!/bin/bash

# VM-only: exercises the shared setup command and real composition for every
# shipped engine. Restore the profile, shortcut settings, and font preference.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

work=$(mktemp -d)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
paths=("$config_home/fcitx5" "$config_home/fontconfig/conf.d/50-omarchy-input-method.conf" "$data_home/dbus-1/services/org.fcitx.Fcitx5.service")
for (( i = 0; i < ${#paths[@]}; i++ )); do
  if [[ -e ${paths[i]} || -L ${paths[i]} ]]; then
    cp -a "${paths[i]}" "$work/backup-$i"
  fi
done

cleanup() {
  close_windows '^org\.omarchy\.ime-test$'
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
  screenshot "success-input-$method-composition"
  wtype -k Return
  sleep 0.3
  wtype -k Return
  wait_until "$method commits text" 15 test -s "$work/result"
  case "$method" in
    mozc) grep -Fxq "日本語" "$work/result" || fail "Mozc commits Japanese" ;;
    hangul) grep -Fxq "한글" "$work/result" || fail "Hangul commits Korean" ;;
    *) python -c 'import pathlib,sys; assert any("\u4e00" <= c <= "\u9fff" for c in pathlib.Path(sys.argv[1]).read_text())' "$work/result" || fail "$method commits Han characters" ;;
  esac
  pass "$method commits composed text"
  fcitx5-remote -c
  close_windows '^org\.omarchy\.ime-test$'
  rm -f "$work/result"
done
