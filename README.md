# TotalFocus

**A native macOS menu bar utility that dims, blurs, and tints everything behind your active windows—helping you stay effortlessly locked into your work.**

<img width="1920" height="1080" alt="Captura de Tela 2026-11-25 at 02 29 19" src="https://github.com/user-attachments/assets/5c911234-f200-4d32-b66b-14aace0b0c41" />

<img width="1920" height="1080" alt="Captura de Tela 2026-11-26 at 01 34 01" src="https://github.com/user-attachments/assets/3fc00da0-fefd-4bba-93e5-29cde5b8a08e" />

<img width="1920" height="1080" alt="Captura de Tela 2026-11-26 at 01 34 19" src="https://github.com/user-attachments/assets/3386a9a5-49d1-40df-a7b5-6f52336d3d5f" />

<img width="1920" height="1080" alt="Captura de Tela 2026-11-26 at 01 34 35" src="https://github.com/user-attachments/assets/1a2336ce-6fd4-4e61-a5f8-ee1106a006c3" />

![macOS](https://shields.io)
![Swift](https://shields.io)
![Version](https://shields.io)
![License](https://shields.io)

---

## ✨ Features

* **Real-Time Optical Backdrop Blur & Grain:** Smoothly blurs and adds subtle film grain behind your active workspace using native CoreAnimation backdrop layers.
* **Two Distinct Focus Presets:**
  * **Ambient:** Soft top-down gradient blur with subtle dimming for everyday browsing and light tasks.
  * **Deep:** Full-screen immersive blur and tint designed for distraction-free writing, coding, and editing.
* **Dynamic Multi-Window Mode (1 to 6 Windows):** Keep up to 6 recent windows sharp side-by-side using tactile `+` and `-` steppers.
* **App-Specific Automation Profiles:** Automatically switch to **Ambient**, **Deep**, or **Pause** when specific apps come into focus—and automatically restore your previous state when you close or leave them.
* **Drag & Drop Rule Management:** Reorder your app rules between *Ambient*, *Deep*, and *Pause* groups simply by dragging their icons.
* **Peek Mode (Hold-to-Reveal):** Hold a customizable shortcut (default `⌃ + Space`) to temporarily reveal your entire desktop, smoothly returning to focus the moment you release the keys.
* **Window Borders & Radial Vignette:** Switch between axial top-to-bottom gradients or a radial aura around your active window, with optional gradient inversion.
* **Custom Tint & Color Wheel:** Pick from native macOS color swatches or open the full system color wheel for custom background tinting.
* **Shake Mouse to Toggle:** Quickly shake your cursor horizontally to toggle focus mode on or off without touching the keyboard.
* **Native macOS Popover:** Adaptive height that respects your Dock (`visibleFrame`), toggleable translucent glass effect, and full Light/Dark/System theme support.

---

## ⌨️ Default Shortcuts

| Action | Default Shortcut | Behavior |
| :--- | :--- | :--- |
| **On / Off** | `⌥ + Space` | Toggles the focus overlay on or off globally |
| **Peek Mode** | `⌃ + Space` | Hold to temporarily reveal the background; release to restore |

> *Both shortcuts can be customized directly from the bottom bar of the TotalFocus popover.*

---

## 🛠️ Installation 

### Requirements
* **macOS 13.0 (Ventura)** or later

---

## 📋 Changelog (`v1.08`)

* **Dynamic Multi-Window Stepper:** Added `+` and `-` controls to keep 1–6 active windows sharp simultaneously with smooth crossfade transitions.
* **App Focus Profiles with Drag & Drop:** Added visual app groups for *Ambient*, *Deep*, and *Pause* with native `/Applications` picker and automatic state restoration.
* **Peek Mode:** Added press-and-release global hotkey support (`⌃ + Space` default) to glance at background windows.
* **Popover Glass & Dock Awareness:** Added a toggle for the translucent popover glass effect and automatic height clamping above the macOS Dock.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
