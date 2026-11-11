# Cloud Courier — Activity 14

Flutter Android app for campus announcements delivered through Firebase Cloud Messaging.
Valid cloud data changes the title and bundled image. The receipt panel shows the handler,
message ID, receipt count, permission, and diagnostic. Invalid data preserves the previous
title and image. The copy button makes the current device token available to the sender
without displaying or logging it.

**Submission:** [answers, reflection, payload, four result rows, and limitations](SUBMISSION.md).

## Run

Use Flutter 3.47.2 / Dart 3.13.2 or a compatible newer SDK and an Android target with
Google Play services. Firebase Core is constrained to 4.x and Messaging to 16.x;
`pubspec.lock` records the exact resolved versions.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d <android-device-id>
```

The Android package `com.parshjadon.cloud_courier` is registered in Firebase project
`temp-fc580`. FlutterFire-generated client options and `google-services.json` are included.
These identifiers are client configuration. No server credentials or device tokens are
committed. The project owner controls permission to send. Only Android is configured.

## Required notification tests

1. Launch the app, allow notifications, and press **Copy current FCM token**. Target that
   installation using Firebase Console's test sender with custom data, or a trusted HTTP
   v1/Admin SDK sender. Use the payload in `SUBMISSION.md`.
2. T1: keep the app visible. Expect `onMessage`, a fresh count, and the event title/image.
3. T2: press Home, send again, and tap the delivered notification. Expect
   `onMessageOpenedApp`, a fresh count, and the event image.
4. T3: dismiss the previously opened app from recents, send, and tap its notification.
   Expect `getInitialMessage`, count 1 on the new launch, and the event image. Do not use
   Android Settings **Force stop** or reopen through the launcher before capturing.
5. T4: keep the app visible, change only `asset` to `unknown`, and send again. Capture
   before and after content to establish that the previous title/image was preserved.
6. Capture one recording or four labeled composite screenshots showing delivery/tap,
   handler, receipt count, and UI. Keep tokens hidden. Record results and evidence
   references in the existing four rows of `SUBMISSION.md`.

Foreground receipt updates the UI without requiring a system banner. A background
notification updates widgets after its tap. The top-level background callback initializes
Firebase and records a message ID without touching widgets. Delivery depends on the
platform, connectivity, payload, and permissions.

## Implementation

- `lib/main.dart`: Firebase startup, registered background entry point, campus UI,
  allowlisted asset selection, diagnostics, and widget lifetime guards.
- `lib/fcm_service.dart`: foreground/open listeners, initial-message consumption,
  permissions, token refresh, one-time initialization, and subscription cleanup.
- `assets/images/`: two original geometric envelope illustrations bundled with the app.
- `test/message_handling_test.dart`: callback/UI tests for valid and repeated data,
  rejection preserving content, initial-message handling, and callbacks after disposal.

Automated tests use a fake service. They verify behavior after a callback; they do not
verify FCM delivery, system notifications, or notification taps. See the submission
document for the observed device-test status.

References: [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup),
[FCM client setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
