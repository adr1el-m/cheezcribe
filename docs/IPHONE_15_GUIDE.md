# LegacyLens • iPhone 15 Quickstart & User Guide

This guide walks you through running, configuring, and presenting **LegacyLens** on an **iPhone 15** (physical device or local iOS simulator).

> 🏆 **Presenting at a Hackathon?** See the full pitch script, 60-second live demo cue card, and judge defense matrix in [PITCH_AND_JUDGING_CARD.md](PITCH_AND_JUDGING_CARD.md).

---

## 📱 Running on Adriel’s iPhone 15

Your physical iPhone 15 (`Adriel’s iPhone 15`, iOS 26.6) is detected and paired!

### Method A: One-Command Run (Terminal)
From the project root:
```bash
./scripts/run-ios-15.sh
```
*The script automatically detects your physical iPhone 15 and launches LegacyLens directly on it! (Falls back to the simulator if disconnected).*

### Method B: Via Xcode (Recommended for first install & signing)
1. Open the workspace in Xcode:
   ```bash
   open app/ios/Runner.xcworkspace
   ```
2. Select **Adriel’s iPhone 15** from the device dropdown at the top.
3. Ensure signing is set to your Personal Team in `Runner -> Signing & Capabilities`.
4. Click **Run (⌘R)**.

---

## ⚡ Option 2: Running on iPhone 15 Simulator

If you want to rehearse on your Mac screen:
```bash
./scripts/run-ios-15.sh
```
*(If the physical phone is unplugged, this boots the local iPhone 15 simulator with iOS 27.0 automatically).*

---

## 🤖 Configuring the AI Engine on iPhone 15

We eliminated Firebase App Check failures on mobile by building a **Direct Google Gemini REST Engine** with persistent on-device storage.

1. In the app header, tap the **AI Engine** status pill (top right).
2. The **AI Engine Diagnostics** sheet opens:
   - **Gemini API Key**: Paste your Gemini API key (or use the built-in default).
   - **Model Selector**: Choose `gemini-2.5-flash` (recommended for speed) or `gemini-2.5-pro`.
   - **Ping Connection**: Tap to test live latency (typically 120ms–200ms) with haptic feedback.
   - Tap **"Save & Connect"** to use the key for the current app session. The app does not persist direct API keys in `shared_preferences`; paste it again after a restart, or configure Firebase AI Logic with App Check.

---

## 🌟 How to Use the Un-Slopped UI

The interface has been redesigned for a mobile-first, Apple-grade experience:

### 1. Documents Tab
- **"Scan Paper with Camera"**:
  - Opens Apple's native **VisionKit Document Scanner**.
  - Point your iPhone 15 camera at any piece of paper, book, or receipt on your desk.
  - Features real-time edge detection, automatic perspective deskewing, and contrast normalization. Scans directly into the native Vision OCR engine!
- **"Import image or PDF"**:
  - Pick any photo or PDF from your Files or Photo Library.
  - Prepared archival files ready in Downloads:
    - 5-page sample: `/Users/adrielmagalona/Downloads/philippinesgeogr00macc_sample_5pages.pdf`
    - Full volume under 15MB: `/Users/adrielmagalona/Downloads/philippinesgeogr00macc_under15mb.pdf`
- **"Try bundled 1915 sample"**:
  - One-tap evaluation fixture for the native OCR and review flow; confirm source and public-demo permission separately.
- **Pinch-to-Zoom Document Viewer**:
  - Natural two-finger pinch-to-zoom and panning.
  - Tap the **eye icon** in the bottom-right of the viewer to toggle glowing **OCR Bounding Boxes** directly over recognized text.
- **Responsive 2-Column Metrics**:
  - Status cards show pages, extracted fields, pending reviews, and verified count without wrapping on narrow screens.

### 2. Review Queue Tab (Superhuman-Style Mobile Flow)
- **Eliminated Mobile Scroll Trap**:
  - Active field detail card is right at the top on mobile.
- **Step-by-Step Stepper**:
  - Use `< Previous` and `Next >` stepper buttons or tap any item in the field roster.
  - Filter between **"Needs Review"** and **"All Fields"**.
- **Evidence-linked review**:
  - Review each uncertain field against its linked source crop before accepting, editing, keeping OCR, or marking it unreadable.
- **Evidence Comparison**:
  - High-resolution **SOURCE CROP** snippet taken directly from the document.
  - Compare on-device **OCR EXTRACTION** against **AI SUGGESTION** with rule justification and priority scores.
- **1-Tap Tactile Actions**:
  - 🟢 **Accept suggestion**: Accepts AI value, marks it verified, and auto-advances!
  - 🔵 **Keep OCR**: Retains raw OCR text and advances.
  - ✏️ **Edit value**: Opens a clean modal sheet to type custom corrections.
  - 🔴 **Mark unreadable**: Marks degraded text unreadable.

### 3. Export Tab (Provenance & Live Preview)
- **Live Export Preview**:
  - View syntax-highlighted JSON, Field CSV, or Records CSV directly in the app.
  - Tap the **Copy icon** to copy data to iOS clipboard.
- **Save to Files**:
  - Export structured files via the native iOS share sheet.
- **Review completion indicator**:
  - Shows when every queued field has an explicit decision; it is not a cryptographic proof or accuracy guarantee.

---

## 🛠️ Verification & Diagnostic Commands

| Task | Command |
|---|---|
| Code analysis (0 issues) | `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && (cd app && ../.tooling/flutter/bin/flutter analyze --no-pub)` |
| Automated tests (10/10 pass) | `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && (cd app && ../.tooling/flutter/bin/flutter test --no-pub)` |
| Connected devices | `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && .tooling/flutter/bin/flutter devices` |
| Launch on iPhone 15 | `./scripts/run-ios-15.sh` |
