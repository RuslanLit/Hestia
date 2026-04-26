# Hestia 4.0.2_3

This release improves incoming call behavior when the Android app is closed or in the background.

## Fixed

- Incoming call push messages now include an Android notification payload in addition to data, using the Hestia calls channel and ringtone sound.
- Added a Firebase default notification channel for Android call notifications.
- Transient call errors, such as unavailable calls, now auto-hide after a short delay.

## Deployment Note

Deploy the updated backend too. The improved closed-app call signaling depends on the new `server.js` push payload.
