echo "Move portable Superwhisper into the packaged dictation backend"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
bindings="$config_home/hypr/bindings.lua"
backend_config="$config_home/omarchy/dictation-backend"

if [[ -f $bindings ]] && grep -Fq -- '-- Superwhisper managed shortcuts BEGIN' "$bindings" && [[ ! -f $backend_config || $(< "$backend_config") == "superwhisper" ]]; then
  omarchy-pkg-add superwhisper-bin
  bash /usr/share/superwhisper/setup-user
  omarchy-dictation backend superwhisper
fi
