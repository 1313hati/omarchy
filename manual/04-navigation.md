# Navigation

Everything in Omarchy happens via the keyboard — _EVERYTHING!_ When the system first starts, you literally can't do a thing with the mouse alone. But you can hit `Super + Space` to reveal the Omarchy Menu and from here you to do just about everything.

But the Omarchy menu is not even intended to be the main way to operate the system most of the time. We can get faster than that! All the most important applications are bound directly to individual hotkeys. You start the terminal with `Super + Return` and a browser with `Super + Shift + Return`. Try doing one after the other, and you'll see the magic of Hyprland's tiling in action:

 ![navigation-browser-terminal](images/navigation-browser-terminal.webp)

You can then hit `Super + J` to stack them on top of each other instead of side by side:

 ![navigation-stacked](images/navigation-stacked.webp)

Hit `Super + J` again to return them to their side-by-side positions. Then try `Super + Shift + Arrow Right` while on the browser to swap the windows.

Now try `Super + Ctrl + T` to start the Activity monitor. That'll appear as a floating window. You can tile it using `Super + T` (and hit that again to make it floating again). Now press `Super + Shift + F` to open the files manager. You'll have a neat four-way setup:

 ![navigation-fourway-tiling](images/navigation-fourway-tiling.webp)

You navigate between the window you want to be active with `Super + Arrow`. This will switch focus and move the cursor to the center of the new application.

If you hit `Super + Shift + 2`, you'll move the current focused application onto the second workspace. `Super + Shift + 1` moves it back. (And `Super + Shift + Alt + 2` will move the current focused application onto the second workspace without switching to it).

If you hold down `Super` and use the mouse to click on a window, you'll be able to rearrange where it sits. If you hold `Super` and use the right button on the mouse, you can freely resize the window.

You close a window on `Super + W` or `Super + Q` (and close all windows on `Ctrl + Alt + Delete`).

You can also go full screen with `Super + F` or even just full-width (keeping the top bar) with `Super + Alt + F` or full-screen within a window with `Super + Ctrl + F` (good for YouTube!).

### Dwindle vs scrolling layout

Omarchy's default layout is called dwindle. It keeps all the windows you open on a single workspace visible at all time, even if it has to shrink them down.

 ![navigation-dwindle-layout](images/navigation-dwindle-layout.webp)

But you can also choose to turn a workspace into the scrolling layout where windows are lined up side-by-side, beyond the visible edge of the display. You turn a single workspace into this layout via `Super + L`.

Pressing `Super + L` again turns the workspace floating, where windows overlap freely and you place them yourself, and a third press returns it to dwindle. A window that floats anyway — one you popped out with `Super + T`, or an app that always opens floating — keeps floating when the workspace goes back to tiling.

 ![navigation-scrolling-layout](images/navigation-scrolling-layout.webp)

The choice is per workspace, and it sticks. So you can keep workspace 1 on dwindle for browsing and workspace 2 on scrolling for code, and they'll come back that way after a restart. (The same toggle is under _Trigger > Toggle > Workspace Layout_ in the Omarchy menu).

If you wish to use the scrolling layout as the default, you can set that in `~/.config/hypr/looknfeel.lua`:

```lua
hl.config({
  general = {
    layout = "scrolling",
  },
})
```

### Floating workspaces

A floating workspace works like a traditional desktop: windows overlap, and you move and size them yourself. Each window gets a titlebar in your theme's colors, with buttons to set it aside, maximize, and close. Click a window to bring it forward. Resize it from any edge or corner.

- Drag a titlebar to the left or right edge of the screen to fill that half. A preview shows where the window will land before you let go.
- Drag a titlebar to the top edge, or double-click it, to maximize the window while keeping the top bar in view. Drag it away from the edge to get its old size back.
- Windows too big to fit in half the screen stay where you drop them rather than overlapping the other half.

To make every workspace float, turn on _Trigger > Toggle > Float All Workspaces_ in the Omarchy menu, or the switch in the Shelf. `Super + L` still gives a single workspace its own layout, and turning floating everywhere off brings back the layouts your workspaces had before.

### The Shelf

`Super + M`, or the minus button in a titlebar, sets a window aside on the Shelf. The app keeps running out of sight, and the Shelf button in the top bar shows how many windows are waiting there. Open the Shelf from that button or with `Super + Alt + M`, and pick a window to bring it back.

The Shelf is shared by all workspaces, and a window comes back to the workspace you are on, not the one it left: set something aside on workspace 2, switch to 4, and restore it there. On a floating workspace it returns to its old size and place; on a tiled one it joins the layout. The Shelf works on any workspace, floating or not, and is separate from the scratchpad.

### Grouping windows

Windows can be grouped using `Super + G`. Once you're in a group, every window you start while that's active will belong to the group. You can move between these grouped windows using `Super + Ctrl + Arrow Left/Right` or `Super + Alt + 1/2/3/4` to go directly to grouped window in order.

You can move a window out of the grouping with `Super + Alt + G` or disassemble the entire group by hitting `Super + G` again. Finally, you can move windows outside the group into it with `Super + Alt + Arrows`.

### Popping windows

You can pop a window out of its workspace allocation with `Super + O`. That'll pin it as a floating window that follows you on whatever workspace you go to. Great for video players and the like.

 ![navigation-popped-window](images/navigation-popped-window.webp)

### Scratchpad workspace

Finally, there's a special scratchpad workspace that drops down over whatever workspace you're currently on, much like a Quake console. Toggle it with `Super + Grave` or `Super + S`, and place a window there using `Super + Shift + Grave` or `Super + Alt + S`.

It works especially well for a terminal running an agent, or for controls you want to interact with quickly without leaving the current workspace. To move a window off the scratchpad, send it directly to another workspace with something like `Super + Shift + 1`.

While the scratchpad holds a single window, it drops down as a centered panel rather than spanning the screen. Put a second app on it and it goes back to the full width, so the two have room to sit side by side.

### It takes some getting used to!

It takes a little while to get used to navigating your desktop like this, but once you do, it'll be hard to go back to a traditional mouse-driven desktop experience!
