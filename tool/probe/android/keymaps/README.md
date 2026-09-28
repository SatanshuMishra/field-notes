# Android key maps

The Android driver taps on-screen keyboard keys, swipe-types words and opens a keyboard's image, clipboard and voice panels by touching fixed screen points. Those points come from a key map: one JSON file per keyboard, recorded on the gate phone.

## Format

Each map is `tool/probe/android/keymaps/<keyboard>.json`, where `<keyboard>` is `gboard` or `samsung`:

```json
{
  "keyboard": "gboard",
  "device": "SM-A546B",
  "screen": [1080, 2340],
  "orientation": "portrait",
  "keys": {
    "a": [102, 1822],
    "space": [540, 2145]
  }
}
```

- `keyboard`: the keyboard the map belongs to, `gboard` or `samsung`.
- `device`: the phone's model, as `adb shell getprop ro.product.model` prints it.
- `screen`: the physical screen size in pixels, width then height, as `adb shell wm size` prints it.
- `orientation`: always `portrait`.
- `keys`: each key's centre as `[x, y]` in physical pixels, with the origin at the screen's top left.

## Required keys

A map holds every one of these keys:

- the letters `a` `b` `c` `d` `e` `f` `g` `h` `i` `j` `k` `l` `m` `n` `o` `p` `q` `r` `s` `t` `u` `v` `w` `x` `y` `z`;
- the digits `0` `1` `2` `3` `4` `5` `6` `7` `8` `9`;
- `space`, `enter`, `backspace` and `shift`;
- `symbols`: the key that switches to the symbols layout;
- `emoji`: the emoji or image button that opens the keyboard's image picker;
- `clipboard`: the clipboard button;
- `voice`: the voice typing button.

A digit that sits on a long-press or on the symbols layout is recorded where the driver can tap it directly, such as the number row when the keyboard shows one.

## Recording

Record both maps on the gate phone as the first Android harness step, before any Android scenario runs:

1. Connect the phone with USB debugging authorised and hold it in portrait.
2. Run `zsh tool/probe/android/drive.sh record-keymap gboard`. The driver switches to Gboard, reads the touchscreen through `adb shell getevent -lt`, and asks for each required key in turn; tap that key once, then press Enter at the prompt.
3. Run `zsh tool/probe/android/drive.sh record-keymap samsung` for Samsung Keyboard the same way.

The driver converts the raw touch coordinates to pixels with the ranges `adb shell getevent -p` reports and the size `adb shell wm size` reports, and writes the map to this folder.

## When to record again

A map belongs to one keyboard on one device. Record it again whenever that keyboard's layout, theme, height or number row setting changes, after a keyboard update that moves keys, or on a different phone. A scenario that needs a map that has not been recorded fails its case with the reason `key map not recorded`.

The recorded maps are the owner's; the driver ships without them.
