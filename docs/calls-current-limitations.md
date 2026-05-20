# Voice Calls Current Limitations

Hestia v0.4.x voice calls are foreground-only.

Both users currently need to have Hestia open and connected to receive calls.
If the Android app is minimized, backgrounded, or suspended by the system, its
WebSocket may not stay alive and incoming calls may not appear.

When the recipient is not reachable, the caller should see:

```text
User is unavailable. Open Hestia on the other device to receive calls.
```

Incoming call offers expire after 30 seconds. If Hestia receives an old call
offer after returning from the background, it must not play the ringtone or show
an incoming call screen. The app records a local "Missed voice call" indicator
instead.

Background incoming calls require additional work:

- Android push delivery through FCM.
- A foreground service or call-style notification to wake/show the incoming
  call UI.
- Careful handling of app lifecycle, permissions, and notification channels.

TURN is also required for many networks. STUN-only calls may fail behind carrier
NAT, strict NAT, VPNs, enterprise Wi-Fi, or firewalls. See
`docs/coturn-production-setup.md` for coturn setup and TURN testing.
