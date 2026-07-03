# Push notifications — Mac setup handoff

Context for finishing the QuoteWall push-notification migration on this Mac.
(This file is working notes for the setup session — delete it before PRing the
branch to bcamp1/QuoteWallApp.)

## What already happened (don't redo)

- The backend (quotewall.vip, a Node server on Sam's home server) already sends
  FCM pushes and is live and verified: quote of the day goes to topic
  `daily-quote` daily at 3:50 PM Mountain, and custom announcements go to topic
  `announcements` via a password-gated compose page at
  https://quotewall.vip/send-notification (admin password: `something`).
- Firebase project: **quotewall403** (Sam's Google account). Server credentials
  are already installed server-side; nothing server-side remains.
- This branch (`push-notifications`, commit 2645c60) already rewrote the app:
  `lib/notifications.dart` now subscribes/unsubscribes FCM topics instead of
  pre-scheduling 50 days of local notifications. The "Daily Quote
  Notifications" checkbox toggles the `daily-quote` topic; `announcements` is
  always subscribed; stale pre-scheduled local notifications are cancelled on
  startup. **This code has never been compiled** — it was written on a Linux
  box with no Flutter SDK. Expect to fix small things.

## What this session must do

1. **Prereqs** — check `flutter doctor`, Xcode + CocoaPods working. Install
   what's missing (flutter via brew or archive; `sudo gem install cocoapods`
   or brew).
2. **Firebase CLI + FlutterFire CLI**
   ```
   npm install -g firebase-tools   # or: brew install firebase-cli
   firebase login                  # interactive, Sam's Google account
   dart pub global activate flutterfire_cli
   ```
3. **Generate the missing file** (the branch imports `lib/firebase_options.dart`,
   which is generated, not committed):
   ```
   flutterfire configure --project=quotewall403
   ```
   Select at least iOS. This registers the iOS app (bundle id
   `com.branson.quotewall`) in Firebase and writes
   `ios/Runner/GoogleService-Info.plist` + `lib/firebase_options.dart`.
4. **`flutter pub get`** — new deps: `firebase_core`, `firebase_messaging`.
   If iOS pod install fails on deployment target, bump `platform :ios` in
   `ios/Podfile` to `13.0` (or `15.0` if firebase_messaging asks for it).
5. **Xcode capabilities** — open `ios/Runner.xcworkspace`, Runner target →
   Signing & Capabilities (Sam's team):
   - add **Push Notifications**
   - add **Background Modes** → check **Remote notifications**
   Automatic signing should add the push entitlement to the App ID; if it
   complains, enable Push Notifications on the `com.branson.quotewall`
   identifier at developer.apple.com → Identifiers.
6. **APNs auth key** (required — iOS gets nothing without it):
   - developer.apple.com → Account → Certificates, Identifiers & Profiles →
     **Keys** → **+** → name e.g. `quotewall-apns`, check **Apple Push
     Notifications service (APNs)** → Register → **Download the .p8**
     (downloadable only once — keep it safe). Note the **Key ID** and the
     **Team ID** (top-right of the portal).
   - Firebase console → project quotewall403 → Project settings → **Cloud
     Messaging** tab → Apple app → **Upload** APNs auth key (.p8 + Key ID +
     Team ID).
7. **Build & test on a physical iPhone** (APNs on simulators is flaky; use a
   real device):
   - run the app, accept the notification permission prompt, leave the
     checkbox on, then background/close the app
   - send a test from https://quotewall.vip/send-notification (password
     above) → the push should arrive within seconds
   - toggle the checkbox off/on to sanity-check the daily-quote topic calls
     (actual daily push fires at 3:50 PM Mountain)
8. **Wrap up**: commit whatever fixes were needed (plus the generated
   `firebase_options.dart` — committing it is fine and normal;
   `GoogleService-Info.plist` too, neither is secret enough to matter for this
   app). Delete this HANDOFF.md in the final cleanup commit, push the branch,
   then PR `push-notifications` → `bcamp1/QuoteWallApp` main.

## Gotchas

- Topic subscription happens at app launch and needs network; first launch
  after install may take a few seconds before a test push can reach the
  device.
- If the notification permission prompt never appears, delete the app from
  the device and reinstall (iOS remembers denials).
- Old installed builds keep firing their pre-scheduled local notifications
  until updated — the new build cancels them on first launch.
