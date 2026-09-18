<div align="center">

# 🎙️ VocalCue

**Ultra Low-Latency Virtual In-Ear Monitor & Live Vocal FX Studio for macOS**

[![Platform](<https://img.shields.io/badge/Platform-macOS%2014.0%2B%20(Sonoma)-blue.svg?style=flat-square&logo=apple>)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Audio](https://img.shields.io/badge/Audio-CoreAudio%20%7C%20AVAudioEngine-purple.svg?style=flat-square)](https://developer.apple.com/documentation/avfaudio)
[![Version](https://img.shields.io/badge/Release-v1.2.0-green.svg?style=flat-square)](https://github.com/MarkeloPuangpoo/vocal-cue/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](LICENSE)

_Turn your Mac, microphone, and headphones into an instant professional stage In-Ear Monitor (IEM) system with real-time vocal processing and master recording._

</div>

---

## ✨ Features

### ⚡ Ultra Low-Latency Audio Engine

- **Near-Zero Latency (~10-20ms):** Direct Core Audio HAL buffer optimization (256 frames @ 48kHz) provides instantaneous auditory feedback essential for pitch accuracy while singing.
- **Audio Device Hot-Swapping:** Automatically detects microphone or headphone plug/unplug events and seamlessly restarts the audio stream without crashes.
- **Smart Feedback Prevention:** Warns and prevents accidental activation when MacBook built-in speakers are selected to eliminate acoustic feedback screeching.

### 🎛️ 6-Stage Studio Vocal DSP Chain

Every microphone signal passes through a dedicated, uninterrupted processing rack:

```
Microphone Input (Mono / Stereo)
   ↓
GainMixer (Input Preamp Gain + Mono-to-Stereo Upmix)
   ↓
AVAudioUnitEQ (80Hz Low-Cut HPF + 3-Band Parametric EQ)
   ↓
DynamicsProcessor (Noise Gate Expansion)
   ↓
AVAudioUnitReverb (Stereo Spatial Ambiance)
   ↓
AVAudioUnitDelay (Echo / Repeat Effects)
   ↓
PeakLimiter (Ear-Safe Brickwall Ceiling @ 0 dBFS)
   │
   ├──────► [Live Recording Tap] ──► 24-bit 48kHz Master WAV
   ↓
MainMixerNode (Headphone Monitor Volume)
   ↓
Headphones / In-Ear Monitors (IEMs)
```

1. **Low-Cut 80Hz (High-Pass Filter):** One-tap toggle filtering out plosive pops ("p", "b" consonants) and low-frequency desk vibrations.
2. **3-Band Parametric EQ:**
   - **Bass (150Hz Shelf):** -12dB to +12dB for chest resonance and body.
   - **Mid (2.5kHz Parametric, Q=1.0):** -12dB to +12dB for vocal clarity and lyric presence.
   - **Treble (8.0kHz Shelf):** -12dB to +12dB for airy brightness.
3. **Smart Noise Gate:** Suppresses background ambient noise (AC hum, computer fan noise) when not actively speaking/singing. Includes real-time `OPEN` / `MUTED` status indicator.
4. **Spatial Reverb:** 13 factory acoustic presets (Medium Hall, Small Room, Large Chamber, Plate, etc.) with Wet/Dry mix.
5. **Echo Delay:** Low-latency repeat delay with millisecond-precision timing and feedback control.
6. **🛡️ Ear-Safe Peak Limiter:** Strict brickwall ceiling at 0 dBFS protects your hearing from sudden audio spikes, dropped mics, or feedback scream.

### 🔴 Master Live Audio Recording Mode

- **Post-Effects Master Capture:** Records your voice with **all active DSP effects included** (EQ + Gate + Reverb + Delay + Limiter).
- **Reference Broadcast Quality:** Uncompressed **24-bit PCM WAV at 48kHz Stereo**, saved automatically to `~/Music/VocalCue Recordings/`.
- **Zero Performance Drop:** Asynchronously written through a dedicated background queue to keep audio rendering 100% jitter-free.
- **Inline Playback Preview:** Listen back to your recorded take immediately inside the app with a built-in waveform player and seek bar.
- **Show in Finder:** One-click shortcut to reveal your WAV file in macOS Finder.

### 🎨 Native Modern macOS Design

- **Glassmorphic Dark UI:** Handcrafted SwiftUI layout with responsive rotary knobs and calibrated dual-channel RMS/Peak meters (-60 to 0 dBFS).
- **Menu Bar Companion:** Compact status icon in the macOS menu bar for quick toggling and background operation.

---

## 🚀 Getting Started

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ or Swift 5.9+ Command Line Tools

### Quick Build & Run

Clone the repository:

```bash
https://github.com/MarkeloPuangpoo/vocal-cue.git
cd vocal-cue
```

Build the release application bundle using the automated script:

```bash
./build.sh
```

Launch the app:

```bash
open "build/VocalCue.app"
```

Or open in Xcode:

```bash
open VocalCue.xcodeproj
```

---

## ⌨️ Shortcuts

| Shortcut | Action                           |
| :------- | :------------------------------- |
| `Space`  | Toggle Audio Engine Start / Stop |
| `⌘ + M`  | Toggle Monitor from Menu Bar     |
| `⌘ + Q`  | Quit VocalCue                    |

---

## 📁 Project Structure

```
vocal-cue/
├── Package.swift               # Swift Package Manager manifest
├── project.yml                 # XcodeGen configuration
├── build.sh                    # Automated release build script
├── VocalCue.xcodeproj          # Generated Xcode project
├── VocalCue/
│   ├── VocalCueApp.swift       # App entry point & MenuBarExtra
│   ├── Info.plist              # Bundle metadata & microphone permission
│   ├── VocalCue.entitlements   # macOS app entitlements
│   ├── Audio/
│   │   ├── AudioEngineManager.swift  # CoreAudio HAL & AVAudioEngine DSP chain
│   │   └── AudioDeviceManager.swift  # Hardware device enumeration & buffer tuning
│   └── Views/
│       ├── ContentView.swift         # Main rack interface
│       ├── AudioProcessingView.swift # Noise Gate, 3-Band EQ & Limiter
│       ├── EffectsView.swift         # Reverb & Delay controllers
│       ├── RecordingView.swift       # Live WAV recorder & inline player
│       ├── ArcKnobView.swift         # Rotary knob controls
│       └── LevelMeterView.swift      # Dual-channel RMS/Peak dBFS meters
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
