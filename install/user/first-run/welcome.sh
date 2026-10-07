# Real newlines, not a literal \n: the card renders the body as it arrives, and
# elides past three lines.
omarchy-notification-send -u critical -g  "Learn Keybindings" \
  $'Super + K for cheatsheet.\nSuper + Space for Omarchy Menu.' \
  --exec omarchy-menu-keybindings

if [[ $(omarchy-input-method status | jq -r .installed_method) == "mozc" ]]; then
  omarchy-notification-send -u critical "Japanese input is ready" \
    $'Click the keyboard indicator in the bar to switch input.\nType nihongo, then press Space twice for character choices.'
fi
