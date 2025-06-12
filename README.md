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
