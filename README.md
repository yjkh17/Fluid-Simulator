# FluidSimApp

Real-time, touch-driven fluid simulation for iOS built with SwiftUI and Metal. Swipe, swirl, and share mesmerizing liquid art at up to 60 fps—even on A13 devices.

<p align="center">
  <img src="preview.gif" width="280" alt="FluidSimApp demo"/>
</p>

---

## ✨ Features

| Category | Details |
|----------|---------|
| Real-time Physics | 2-D Navier–Stokes solver with vorticity confinement, diffusion, and advection. |
| GPU Powered | Single Metal command buffer per frame; adaptive grid (64² → 512²). |
| Visual FX | Bloom, sun-rays, customizable color palettes, and LUT support. |
| Multi-Touch | Unlimited fingers = unlimited splats. Touch clusters mapped to impulse forces. |
| Haptics & Audio | Subtle haptics on impulse, optional bubbling SFX. |
| Export | One-tap PNG or 15 s H.264 video for TikTok/Reels. |
| Accessibility | Dynamic Type, color-blind palettes, haptic toggle. |
| Low-Power Mode | Auto-drops to 30 Hz + disables bloom when battery < 20 %. |

---

## 📂 Project Structure

## 🖥️ macOS Screen Saver

The repository now ships a macOS screen saver target that mirrors the WebGL demo’s fluid effect:

1. Open `Fluid Simulator.xcodeproj` in Xcode 16.4 or newer.
2. Select the **FluidSaver** target and choose **My Mac** as the run destination.
3. Build (`⌘B`). Xcode outputs `FluidSaver.saver` under `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/`.
4. Install by double-clicking the built `.saver` (or copy it into `~/Library/Screen Savers/`), then pick **FluidSaver** in System Settings → Screen Saver.

Notes:
- The saver runs at 60 fps (`animationTimeInterval = 1/60`), clamps large `dt` values after wake to avoid instability, and continues evolving while idle thanks to in-sim fading.
- Mouse movement injects velocity and dye without clicks; preview mode uses the same pipeline on the smaller view.
