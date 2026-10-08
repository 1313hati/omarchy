# Text Extraction & Dictation

### Text Extraction

Hit `Super + Ctrl + PrtScr` to select a region on the screen for text extraction. The tesseract open source OCR model will then quickly convert that selection into text and place it on the clipboard. Then you just hit `Super + V` to paste.

This is very helpful for grabbing addresses out of image footers or phone numbers embedded in website headlines.

 ![text-extraction](images/text-extraction.webp)

### Dictation

Install [Voxtype](https://voxtype.io/) or [Superwhisper](https://superwhisper.com/) through _Setup > Defaults > Dictation_ in the Omarchy menu. Selecting a backend installs it if needed and makes it the default for dictation. Voxtype loads a base English model that takes up 150MB; change the model with `voxtype setup model` and other settings through `~/.config/voxtype/config.toml`. Superwhisper opens its settings to choose cloud or local processing, and OPR keeps the application updated.

Once installed, you dictate by holding down `Right Alt` or `F9`, or by toggling with `Super + Ctrl + X`, and the dictated text will appear in the focused input area. On keyboard layouts where Right Alt is AltGr, use `F9` to keep AltGr available for typing.

The same shortcuts can use an installed Superwhisper instead. Select your backend with `omarchy dictation backend voxtype` or `omarchy dictation backend superwhisper`. Run `omarchy dictation backend` to see which one is selected. Without an explicit selection, Omarchy uses Voxtype when installed, otherwise Superwhisper.

Omarchy loads the selected backend's desktop integration automatically. No Superwhisper configuration is needed in `~/.config/hypr/`; selecting a backend removes Superwhisper's old generated block from `bindings.lua` with a backup, preserving personal bindings.

Custom bindings and scripts can use `omarchy dictation start`, `omarchy dictation stop`, and `omarchy dictation toggle`. The selected backend handles the recording and transcription. Selecting Superwhisper disables its native hold shortcut and sets its native toggle to `Alt + Space`, keeping it separate from Omarchy's recording keys. Superwhisper requires at least one native recording shortcut, and its cancellation shortcut stays available. If Superwhisper was selected automatically, run `omarchy dictation backend superwhisper` once to configure these shortcuts.
