# Sprig

<img width="813" height="505" alt="image" src="https://github.com/user-attachments/assets/68522d23-873a-4934-96dd-258f92dfd5e4" />

<img width="657" height="596" alt="image" src="https://github.com/user-attachments/assets/9d79eb18-2cf3-45cd-b1f6-03098656f632" />



A small macOS menu bar app that gives you a floating keyboard, knobs and sliders, that can send MIDI to a specified output and channel. 

I got tired of opening a DAW just to fire off a few test MIDI notes.


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

## Usage

Click the icon in the menu bar to show or hide each window, and to choose the MIDI output and channel.

On the keyboard, drag the right edge to add keys upward and the left edge to set the lowest note. The ← and → buttons, or Z and X, move up and down an octave. The computer keys play notes while the keyboard window is focused.

On the knobs and sliders, drag the side edges to add or remove columns. Drag the bottom edge of the sliders window to make them longer. 
**All Notes Off** is available in the menu.

## License

GPL-3.0. See [LICENSE](LICENSE).
