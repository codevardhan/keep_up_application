# KeepUp — Flutter App (iOS & Android)

A lightweight “stay-in-touch” assistant. KeepUp helps you set connection goals, organize contacts into circles with cadences (daily/weekly/biweekly/monthly), and get **AI-generated, natural-language** nudges via local notifications.

This README tells you how to **clone, configure, build, run, and test** the app on both iOS and Android.

---

## Prerequisites

* **Flutter**: 3.22+ (`flutter --version`)
* **Dart**: 3.x (bundled with Flutter)
* **Xcode**: 15+ (for iOS); CocoaPods: `gem install cocoapods`
* **Android Studio**: latest; Android SDK + platform tools
* **A physical device or simulator/emulator**
* **Developer accounts/signing**:

  * iOS: Apple Developer Program (for device runs & notifications)
  * Android: No account needed for local builds

> Tip: run `flutter doctor -v` and resolve any red items before continuing.

---

## 1) Clone & Install

```bash
git clone git@github.com:codevardhan/keep_up_application.git
cd keep_up_application
flutter pub get
```

---

## 2) Environment & Secrets

The app uses **dotenv** to load non-checked-in keys and flags.

Create the file: `assets/env/.env` (and keep it **untracked**).

```env
# assets/env/.env
# Anthropic API key (if using AI for notifications/messages)
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxx
```

---

## 3) Platform Permissions & Setup

### Android

**Device Setup**

* Enable **USB debugging** (Developer Options).
* Start an emulator or connect a device: `adb devices`.

---

### iOS

Open iOS project once to install pods and set signing:

```bash
cd ios
pod install
cd ..
```

**Capabilities & Info.plist**
In Xcode (Runner target):

* **Signing & Capabilities** → add your **Team**.
* **Background Modes**: not required for basic local notifications, but fine to keep off.
* **Info.plist**: add usage descriptions:

```xml
<key>NSContactsUsageDescription</key>
<string>KeepUp uses your contacts so you can quickly pick people to stay in touch with.</string>
<key>NSUserNotificationUsageDescription</key>
<string>KeepUp sends gentle reminders when it's time to check in.</string>
```

Run on a device once to trust the developer profile if needed.

---

## 4) Running the App

### Android

```bash
flutter pub get
flutter run -d emulator-5554         # or the ID from `flutter devices`
# or simply:
flutter run
```

### iOS

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace          # set Signing Team if first time
# then from terminal:
flutter run -d <iOS_DEVICE_ID>
```

If you see a signing error, open Xcode → **Runner** → set **Team** and **Bundle Identifier**, then `Product > Run`.

---

## 5) Features to Demo

* **Onboarding**: first launch only; requests **Notifications** and **Contacts** permissions (cannot be skipped once enforced).
* **Circles & Cadence**: Manage circles and per-contact cadence overrides.
* **AI Suggestions**: Goal-aware text (Anthropic)
* **Local Notifications**: BigText layout so the **full message** is visible.
  Title is **“Check in”** and body contains the full AI text.

### Send a Demo Notification (Settings → Demo)

1. Go to **Settings**.
2. Tap **“Send demo suggestion notification”**.
3. It selects a contact in your circles and pushes a **BigText** notification with the AI text.
   Tap the notification to open the **Compose** screen with the text prefilled.

---


## 6) Troubleshooting

* **Notifications don’t appear**

  * Android 13+: ensure runtime permission granted.
  * iOS: check **Settings > Notifications** for the app; ensure allowed.
  * Make sure `NotificationService.init()` is called before scheduling.

* **Notification text truncates**

  * We use `NotificationLayout.BigText` and set **body to the full message**.
  * Title is the short “Check in”; body contains the long text so it’s fully visible when expanded.

* **Contacts empty**

  * Ensure permission granted and device has contacts.
  * Simulators may not have contacts; test on real devices or import dummy contacts.

* **Anthropic 400 “Unexpected role system”**

  * We fixed the API usage to use **top-level `system`** (not as a message role) and split the API client into `ai_client.dart`.
  * Ensure `ANTHROPIC_API_KEY` is set if using remote AI.

* **“Don’t use BuildContext across async gaps”**

  * We captured `Navigator` / `ScaffoldMessenger` before `await` and use `mounted` guards. Make sure your local changes follow the same pattern.

---

## 7) Known Limitations (MVP)

* Contacts syncing is one-shot; re-sync available via **Settings**.
* AI depends on Anthropic if key present
* Background exact alarms not required; we JIT schedule **evening BigText** nudges.
