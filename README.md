# 🎬 GoPrompt: Professional Cinematic Teleprompter

GoPrompt is a premium iOS Teleprompter application engineered for content creators, broadcasters, and professionals. Designed with a strict focus on **Cinematic Excellence**, it leverages advanced hardware controls, real-time depth processing, and a fluid, physics-based scrolling engine to deliver a seamless and distortion-free recording experience. 

The application is built entirely in **SwiftUI**, integrating deeply with **AVFoundation**, **Metal**, and **CoreML** to provide features typically reserved for high-end studio setups.

---

## 🎨 Design Philosophy: "The Obsidian Lens"

The UI intentionally moves away from a "standard app" aesthetic, embodying **The Obsidian Lens** philosophy. It feels like a high-end piece of optical equipment: 
- **Glassmorphism**: A UI that is virtually invisible until needed, characterized by high-contrast typography floating over deep, translucent glass. 
- **Tonal Depth**: Breaking the template look through intentional negative space and tonal layering, ensuring the speaker’s focus remains strictly on the script.
- **Asymmetric Balance**: Placing controls in ergonomic clusters rather than rigid, centered grids to mimic a professional cinema camera’s viewfinder.

---

## 📸 Application Interface & Functionality

The application faithfully matches these high-fidelity design specifications, ensuring parity between the intended premium aesthetic and the actual, hardware-backed iOS experience.

### 1. Recording Studio
<img src="StitchDesigns/RecordingScreen.png" width="250" />

**Functionality:** Focus on minimal glass controls and asymmetric balance.
**Key Feature:** Eye Contact Preservation Layout. The script reading zone is mathematically constrained to the top 15% (portrait) and dynamically mapped to the physical location of the camera hardware, guaranteeing the speaker's eyes never drift from the lens.

### 2. Script Library
<img src="StitchDesigns/ScriptLibrary.png" width="250" />

**Functionality:** Minimalist typography (Plus Jakarta Sans). Data-driven list mapped to local CoreData/JSON storage.

### 3. Rich Text Script Editor
<img src="StitchDesigns/ScriptEditor.png" width="250" />

**Functionality:** Distraction-free deep writing mode. Real-time keystroke synchronization updating Word Count metrics.

### 4. Recording Gallery
<img src="StitchDesigns/RecordingGallery.png" width="250" />

**Functionality:** Directly review recorded content with quick access playback controls and share options embedded into the premium glass aesthetic.

### 5. Settings & Configuration
<img src="StitchDesigns/Settings.png" width="250" />

**Functionality:** High-contrast metallic toggles and hardware-coupled context menus mapped to app state (e.g., Cinematic Depth and Green Screen options).

---

## 🏗 System Architecture & Engine

GoPrompt relies on a clean, scalable architecture designed specifically to manage heavy rendering threads without impacting the SwiftUI main loop. 

### 1. Dual-Track Preview Strategy
- **`CameraPreviewView`**: Bridged via `UIViewRepresentable` mapping directly to `AVCaptureVideoPreviewLayer` for highly performant, standard low-power rendering.
- **`MetalPreviewView`**: A custom `MTKView` used for computational rendering when applying Real-time Filters, Green Screen, or Cinematic Depth of Field.

### 2. The Teleprompter Engine (`CADisplayLink`)
Instead of relying on SwiftUI's layout cycle for animations (which can lead to dropped frames), GoPrompt utilizes a dedicated `CADisplayLink` engine.
- **Dynamic Physics System**: Automatically calculates baseline velocity using a target of 140 WPM.
- **Ease-in Acceleration**: Employs a **2-second cubic interpolation curve** (`t^2 * (3 - 2t)`) at the start of recordings, ensuring text ramps up to speed smoothly rather than jumping immediately. 
- **MainActor Isolation**: While the hardware pipeline exists on concurrent background threads, the Teleprompter Engine is strictly `@MainActor` isolated to prevent race conditions when shifting `scrollOffset`.

### 3. Source-Time Synchronization (A/V Accuracy)
For Cinematic/Filtered modes requiring `AVAssetWriter`, the app manually captures raw video and audio streams. 
- **The "Uptime Gap" Solution**: GoPrompt uses the exact `presentationTime` of the *very first* video frame received to initialize the muxing session. This completely avoids iOS audio drift or silent playback bugs common when mixing real-time ML processing with raw microphone input.

### 4. Hardware Session Guard Pattern
To eliminate the critical failure state of "Ghost Recordings" (scrolling without saving), the app wraps captures in asynchronous verifiers:
- Asynchronous `cameraService.isSessionRunning` checks block the Teleprompter initialization until the Capture Session is fully warmed up and active.

### 5. Architectural Animation Isolation
Layout updates during recording (like toggling specific settings) are structurally separated into **Layer 1** (Background / Camera Feed) and **Layer 2** (Foreground Floating Controls). This completely isolates the heavy Metal preview frames from SwiftUI state invalidation, preserving battery life and thermal headroom.

---

## 🛠 Tech Stack

- **UI Framework:** SwiftUI, UIKit (for specialized hosting)
- **Audio/Video Pipeline:** AVFoundation (`AVCaptureSession`, `AVAssetWriter`)
- **Computer Vision:** CoreML (`VNGeneratePersonSegmentationRequest` for cinematic depth extraction)
- **High-Performance Rendering:** Core Image, Metal (`MTKView`)
- **App Data & Persistence:** Codable JSON state managed via `ScriptStorageService`
- **Design Mockups:** Stitch Design System

## 🚀 Quick Run Guide

To run the project locally, ensure you have the required development environment:

1. Clone the repository.
2. Open `TeleprompterApp.xcodeproj` in Xcode 16+.
3. Select an active iOS Device (Simulator does not support the full AV camera suite).
4. Build and Run (`Cmd + R`).

*Note: For Fastlane deployment and App Store metadata management, reference the `fastlane/` directory.*
