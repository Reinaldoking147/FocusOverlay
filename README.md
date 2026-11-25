
**FocusOverlay** is a lightweight, native **macOS** menu bar utility designed to keep your full attention on the active window by applying real-time optical blur, cinematic film grain, directional gradients, and customizable background tinting to everything behind it.

<img width="1920" height="1080" alt="Captura de Tela 2026-11-25 at 02 29 19" src="https://github.com/user-attachments/assets/5c911234-f200-4d32-b66b-14aace0b0c41" />


---

## ✨ Features

* **Real-Time Optical Backdrop:** Hardware-accelerated CoreAnimation backdrop blur (`CABackdropLayer`) that dynamically tracks and stays right behind your active window across multiple displays and Spaces.
* **Dual Focus Presets (`Ambient` & `Deep`):**
  * **Ambient:** Light optical blur with subtle vertical gradient fade for relaxed multitasking.
  * **Deep:** Immersive focus mode with deeper blur and balanced tinting for distraction-free work.
  * Continuous **60fps parameter interpolation** when switching between modes, plus one-click **Reset** to recalibrated factory defaults.
* **Customizable Tint Layer:**
  * Adjust tint intensity and choose from native macOS accent colors or open the full **macOS Color Wheel (`NSColorPanel`)** via a collapsible sequential swatch picker.
  * Colors are saved independently per focus mode.
* **Cinematic Film Grain & Directional Gradients:**
  * Fine-tune organic noise texture and switch between axial fade or radial **Window Borders** aura mode (with gradient inversion support).
* **Quick Toggle Gestures & Shortcuts:**
  * **Customizable Global Shortcut:** Record any key combination directly in the app footer (default: `⌥ + Space`).
  * **Mouse Shake Gesture:** Quickly shake your cursor horizontally to toggle the overlay on or off, with adjustable sensitivity.
* **Native macOS Integration:**
  * Lives cleanly in the menu bar with a dynamic monitor status icon.
  * Supports **System, Light, and Dark** appearances, **Launch at Login**, and built-in **GitHub Release update checks**.

---

## 🚀 Installation

### Download Prebuilt Release
1. Go to the [**Releases**](https://github.com) page.
2. Download the latest `FocusOverlay.zip` (or `.dmg`).
3. Move **FocusOverlay.app** to your `/Applications` folder and launch it.

---

## 🛠️ Tech Stack

* **Swift & SwiftUI** for the native popover control panel and custom menu bar icon.
* **AppKit & QuartzCore (`CABackdropLayer` / `CAFilter`)** for real-time window tracking and GPU-composited visual effects.
* **Carbon Events & ServiceManagement** for global hotkeys and native Login Item integration.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
