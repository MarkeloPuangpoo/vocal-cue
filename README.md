<div align="center">

# 🎙️ VocalCue

**Ultra Low-Latency Virtual In-Ear Monitor & Live Vocal FX Studio for macOS**

[![Platform](<https://img.shields.io/badge/Platform-macOS%2014.0%2B%20(Sonoma)-blue.svg?style=flat-square&logo=apple>)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Audio](https://img.shields.io/badge/Audio-CoreAudio%20%7C%20AVAudioEngine-purple.svg?style=flat-square)](https://developer.apple.com/documentation/avfaudio)
[![Version](https://img.shields.io/badge/Release-v1.3.0-green.svg?style=flat-square)](https://github.com/MarkeloPuangpoo/vocal-cue/releases/latest)
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
5. **Echo Delay & BPM Sync:** Low-latency repeat delay with millisecond-precision timing, feedback control, and automatic metronome tempo subdivision synchronization (1/4, 1/8, dotted 1/8, 1/16).
6. **🛡️ Ear-Safe Peak Limiter:** Strict brickwall ceiling at 0 dBFS protects your hearing from sudden audio spikes, dropped mics, or feedback scream.

### 🎵 Rehearsal Backing Track Player
- **Headphone Monitor Mixing:** Load MP3, WAV, M4A, or FLAC tracks into your in-ear monitor mix with independent **Vocal vs. Music Faders**.
- **Real-Time Key Shift:** Pitch-shift backing tracks from **-12 to +12 semitones** (±1 Octave) via `AVAudioUnitTimePitch` without affecting audio speed.
- **Tempo Adjustment:** Speed up or slow down playback from **50% to 150%** tempo while keeping pitch locked.
- **A-B Rehearsal Looper:** Set Point A and Point B markers to seamlessly repeat difficult vocal passages in continuous loop practice.

### ⏱️ In-Ear Metronome & Tap Tempo
- **In-Ear Only Click:** Crisp procedural tick synthesized directly to monitor output without bleeding into vocal recordings or microphone input.
- **Interactive Tap Tempo:** Real-time beat averaging for instant tempo alignment.
- **Automatic Delay Synchronization:** Locks Echo delay intervals directly to the current BPM.

### 🎯 Real-Time Vocal Pitch Meter
- **Precision Fundamental Tracking:** Fast Accelerate (`vDSP`) autocorrelation detects singer pitch with zero audio latency penalty.
- **Cents Deviation Gauge:** Visual gauge indicating flat/sharp deviation (-50 to +50 cents) with a glowing green sweet-spot target (±10 cents).
- **Exact Note & Frequency:** Clear readouts for Note name (e.g., `A4`, `C♯3`) and frequency in Hz.

### 🔴 Dual-Track (Dry + Wet) Recording & M4A Export
- **Parallel Dry & Wet Capture:** Simultaneously saves both **unprocessed vocal input (Dry)** and **post-effects studio master (Wet)** in broadcast 24-bit 48kHz WAV format.
- **Multi-Take Management:** Built-in take library with instant A/B preview switching between Dry and Wet tracks.
- **M4A Export:** One-click conversion to compressed AAC `.m4a` format for instant sharing and AirDrop.

### 📊 Spectrum Analyzer & Interactive EQ Curve
- **1024-Point Real-Time FFT:** High-resolution audio spectrum display with logarithmic frequency bands (20Hz to 20kHz) and smooth peak decay.
- **Visual EQ Transfer Curve:** Neon response curve dynamically plots the mathematical filter response of the 80Hz Low-Cut and 3-Band Parametric EQ.

### 🎨 Native Modern macOS Design

- **Studio Rack Tabs:** Organized view modes for `DSP & EQ`, `FX & Tempo`, `Backing Track`, and `Takes Library`.
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
