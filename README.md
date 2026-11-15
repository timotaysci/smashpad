# smashpad 🎹💥

**A toddler-proof notepad for Emacs.**

Your toddler wants to bash your keyboard. Your Emacs session has three hours of unsaved work in it. `smashpad-mode` fixes both: it opens a fullscreen frame with huge, centred, rainbow-coloured letters and locks Emacs down. Mash away. `C-x C-c`, `M-x`, `C-g`, `C-z`, mouse clicks and the window close button all do nothing.

## Install

Clone the repo and add it to your config:

```elisp
(add-to-list 'load-path "~/path/to/smashpad")
(require 'smashpad)
```

Or with `use-package` (Emacs 30+ or the `vc` backend):

```elisp
(use-package smashpad
  :vc (:url "https://github.com/CHANGEME/smashpad"))
```

## Use

`M-x smashpad`, then hand over the keyboard.

**To exit, press `Ctrl+Shift+p` three times in a row.** Pressing any other key in between resets the count, so random mashing won't get out.

| Key                  | What it does                           |
|----------------------|----------------------------------------|
| Letters, numbers, symbols | Type, in a random colour          |
| `RET` / `TAB`        | New line / space                       |
| `DEL` / Backspace    | Delete the last character              |
| Everything else      | Nothing                                |
| `C-S-p` ×3           | Exit                                   |

### Emergency exit

If you're ever stuck, run this from another terminal:

```sh
emacsclient -e '(smashpad-mode -1)'
```

## Customise

`M-x customize-group RET smashpad`

| Option                     | Default        | Meaning                                          |
|----------------------------|----------------|--------------------------------------------------|
| `smashpad-exit-key`        | `"C-S-p"`      | Exit key (one event, in `kbd` format)            |
| `smashpad-exit-presses`    | `3`            | How many presses in a row to exit                |
| `smashpad-text-height`     | `4.0`          | Text size relative to your default font          |
| `smashpad-margin-fraction` | `0.15`         | Width of each side margin                        |
| `smashpad-buffer-name`     | `"*smashpad*"` | Set to `"*scratch*"` to use the scratch buffer   |
| `smashpad-new-frame`       | `t`            | Open a new fullscreen frame                      |
| `smashpad-allow-backspace` | `t`            | Let Backspace delete                             |
| `smashpad-colors`          | a rainbow      | Colours for typed letters (`nil` for plain text) |

## How it works

Emacs looks up each key in a stack of keymaps. The one at the top of that stack is `overriding-terminal-local-map`. It beats major modes, minor modes, Evil and the minibuffer. Smashpad puts its own keymap there, and that keymap has a single *default binding* (`[t]`), which matches every event. So every key, chord and mouse click goes to one function. That function types the printable keys and ignores everything else.

A few events skip the keymap stack and go through `special-event-map`. One of these is clicking the window's close button, which arrives as a `delete-frame` event. Smashpad blocks `delete-frame` and `iconify-frame` while it's on. A `post-command-hook` puts the lock back if anything else replaces it.

## Limits

Emacs only sees keys your desktop passes to it. It can't block shortcuts your OS or window manager handles first, such as Super, Alt+Tab, Ctrl+Alt+Del, Ctrl+Alt+F1–F7 (switching to another console) or the power button. If you want to block those too, turn off the shortcuts for the session or use a kiosk/keyboard-lock tool.

In a text terminal, `Ctrl+Shift+p` looks the same as `Ctrl+p`, so the default exit key won't work there. Use a graphical Emacs, or set `smashpad-exit-key` to something else.

## Development

```sh
make test      # run the ERT suite
make compile   # byte-compile, warnings as errors
```

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
