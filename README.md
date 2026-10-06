# Sprig

A small macOS menu bar app that gives you a floating keyboard, knobs and sliders, sending MIDI to whatever you have open.

Handy when you want to play or tweak something without reaching for hardware:

- Trying out a synth or plugin while you build a patch
- Sketching ideas on a laptop away from your controller
- Mapping a few CCs in your DAW without plugging anything in

## Features

- Lives in the menu bar, no Dock icon
- Three windows you can show on their own: **Keyboard**, **Knobs** and **Sliders**
- Play the keyboard with the mouse or the computer keys (A to ;, with the row above for the black keys)
- Drag a window's edges to add keys or columns; the keys and controls keep their size
- Right-click a knob or slider to change its CC or rename it
- Pin any window above other apps
- Zoom each window with its − and + buttons, or ⌘+ and ⌘−
- Sends to any MIDI output on any channel, including the IAC bus for apps on the same Mac
- Light, dark or system theme
- Remembers your windows, ranges, CCs and values between launches

## Install

Build it yourself: clone with `--recursive` to get the [compost](https://github.com/charCulbert/compost) submodule, open `Sprig.xcodeproj` in Xcode and press Run. Requires macOS 14.5 or later.

```
git clone --recursive https://github.com/charCulbert/sprig-midi.git
```

No special permissions are needed. Sprig only sends MIDI; it never reads any.

## Usage

Click the knob icon in the menu bar to show or hide each window, and to choose the MIDI output and channel.

On the keyboard, drag the right edge to add keys upward and the left edge to set the lowest note. The ← and → buttons, or Z and X, move up and down an octave. The computer keys play notes while the keyboard window is focused.

On the knobs and sliders, drag the side edges to add or remove columns. Drag the bottom edge of the sliders window to make them longer. Each control starts on its own CC: knobs on 21 to 36, sliders on 41 to 56.

Choose **All Notes Off** in the menu if anything gets stuck.

## Development

Open `Sprig.xcodeproj` and press Run. The windows are web pages in a `WKWebView`, built from [compost](https://github.com/charCulbert/compost) components, and Swift does the windows, menu, state and CoreMIDI. A build step copies the pages into the app along with only the compost files they import.

## License

GPL-3.0. See [LICENSE](LICENSE).
