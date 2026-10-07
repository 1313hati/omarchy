#!/bin/bash

set -euo pipefail
source "$(dirname "$0")/base-test.sh"

tmp=$(mktemp -d)
cleanup() {
  for child in $(jobs -pr); do kill "$child" 2>/dev/null || true; done
  if [[ -f $tmp/recorder-pid ]]; then kill "$(<"$tmp/recorder-pid")" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/runtime" "$tmp/recordings"
mkfifo "$tmp/release"

cat >"$tmp/bin/omarchy-capture-screenrecording-process" <<'SH'
#!/bin/bash
if [[ ${1:-} != "--pid" || $2 == "123" ]]; then
  if [[ ${TEST_ROLE:-} == "old-status" && ${2:-} == "123" ]]; then
    touch "$TEST_STATE/checked"
    read -r _ <"$TEST_STATE/release"
  fi
  exit 1
fi
[[ -f $TEST_STATE/recorder-pid && $2 == "$(<"$TEST_STATE/recorder-pid")" ]] || exit 1
if [[ ${3:-} == "--signal" ]]; then kill -TERM "$2"; else kill -0 "$2" 2>/dev/null; fi
SH
cat >"$tmp/bin/wf-recorder" <<'SH'
#!/bin/bash
echo "$$" >"$TEST_STATE/recorder-pid"
for arg in "$@"; do
  if [[ ${next:-} == 1 ]]; then touch "$arg"; break; fi
  [[ $arg == "-f" ]] && next=1
done
trap 'exit 0' TERM INT
while true; do sleep 0.05; done
SH
cat >"$tmp/bin/pactl" <<'SH'
#!/bin/bash
case $1 in
  get-default-sink) echo desktop ;;
  get-default-source) echo microphone ;;
  load-module)
    id=$(<"$TEST_STATE/next-module")
    echo $(( id + 1 )) >"$TEST_STATE/next-module"
    touch "$TEST_STATE/module-$id"
    echo "$id"
    ;;
  unload-module) rm -f "$TEST_STATE/module-$2" ;;
esac
SH
cat >"$tmp/bin/flock" <<'SH'
#!/bin/bash
[[ ${TEST_ROLE:-} == "new-start" ]] && touch "$TEST_STATE/lock-attempted"
exec /usr/bin/flock "$@"
SH
cat >"$tmp/bin/omarchy-cmd-present" <<'SH'
#!/bin/bash
[[ $1 == "wf-recorder" ]]
SH
cat >"$tmp/bin/omarchy-hyprland-monitor-focused" <<'SH'
#!/bin/bash
echo Virtual-1
SH
cat >"$tmp/bin/ffmpeg" <<'SH'
#!/bin/bash
if [[ ${TEST_ROLE:-} == "old-stop" && ! -e $TEST_STATE/checked ]]; then
  touch "$TEST_STATE/checked"
  read -r _ <"$TEST_STATE/release"
fi
touch "${@: -3:1}"
SH
for command in omarchy-shell omarchy-notification-send ffprobe pkill; do
  printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/$command"
done
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$ROOT/bin:$PATH" TEST_STATE="$tmp" XDG_RUNTIME_DIR="$tmp/runtime"
export OMARCHY_SCREENRECORD_DIR="$tmp/recordings"
record="$ROOT/bin/omarchy-capture-screenrecording"

wait_for() {
  for _ in {1..200}; do
    for file in "$@"; do [[ ! -e $file ]] || return 0; done
    sleep 0.01
  done
  fail "concurrent recording command reached its barrier" "$*"
}

assert_recording() {
  [[ -s $XDG_RUNTIME_DIR/omarchy-screenrecord-pid && -s $XDG_RUNTIME_DIR/omarchy-screenrecord-filename ]] ||
    fail "the new recording retains its saved state"
  [[ -f $XDG_RUNTIME_DIR/omarchy-screenrecord-pa-modules ]] || fail "the new recording retains its audio mix"
  for module in $(<"$XDG_RUNTIME_DIR/omarchy-screenrecord-pa-modules"); do
    [[ -f $tmp/module-$module ]] || fail "the new recording's audio module stays loaded" "$module"
  done
}

echo 123 >"$XDG_RUNTIME_DIR/omarchy-screenrecord-pid"
printf '10\n11\n12\n' >"$XDG_RUNTIME_DIR/omarchy-screenrecord-pa-modules"
touch "$tmp/module-10" "$tmp/module-11" "$tmp/module-12"
echo 20 >"$tmp/next-module"
TEST_ROLE=old-status "$record" --status >/dev/null 2>&1 & old=$!
wait_for "$tmp/checked"
TEST_ROLE=new-start "$record" --fullscreen --resolution=1280x800 --with-desktop-audio --with-microphone-audio >/dev/null 2>&1 & new=$!
wait_for "$tmp/lock-attempted" "$tmp/recorder-pid"
if [[ ! -e $tmp/lock-attempted ]]; then
  wait_for "$XDG_RUNTIME_DIR/omarchy-screenrecord-pid"
  for _ in {1..200}; do
    [[ $(<"$XDG_RUNTIME_DIR/omarchy-screenrecord-pid") == 123 ]] || break
    sleep 0.01
  done
  [[ $(<"$XDG_RUNTIME_DIR/omarchy-screenrecord-pid") != 123 ]] || fail "the concurrent recording saves its PID"
fi
echo release >"$tmp/release"
status=0
wait "$old" || status=$?
(( status == 1 )) || fail "the old status reports its exited recorder" "$status"
wait "$new" || fail "the new recording starts"
assert_recording
pass "stale status cleanup cannot unload a concurrent new recording's audio"

rm -f "$tmp/checked" "$tmp/lock-attempted"
TEST_ROLE=old-stop "$record" --stop-recording >/dev/null 2>&1 & old=$!
wait_for "$tmp/checked"
rm "$tmp/recorder-pid"
stop_locked=0
if ! /usr/bin/flock -n "$XDG_RUNTIME_DIR/omarchy-screenrecord.lock" true; then stop_locked=1; fi
TEST_ROLE=new-start "$record" --fullscreen --resolution=1280x800 --with-desktop-audio --with-microphone-audio >/dev/null 2>&1 & new=$!
wait_for "$tmp/lock-attempted" "$tmp/recorder-pid"
if (( ! stop_locked )); then
  wait "$new" || fail "the concurrent recording starts while the old stop is paused"
  new=""
fi
echo release >"$tmp/release"
wait "$old" || fail "the old recording stops"
if [[ -n $new ]]; then
  wait "$new" || fail "another recording starts after stop"
fi
assert_recording
pass "a finishing stop cannot remove a concurrent new recording's state"
