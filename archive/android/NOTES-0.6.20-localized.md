# Android Localized Wake-Up Build

Build: hestia-0.6.20-android-localized-wakeup.apk

Includes:
- stable Android wake-up / foreground-service reachability source checkpoint
- localized Flutter Always reachable prompt
- localized native Android call notifications
- localized native lock-screen IncomingCallActivity labels
- localized native notification channels
- localized user-facing system/error messages added after 0.6.19 artifact

Known working inherited from checkpoint:
- incoming calls after memory cleanup
- Google Services Android
- no-Google Android foreground service fallback
- notification Accept path works
- call connects after wake
- message notifications still work

Known limitations:
- splash -> accept screen -> connect UX
- brief ringtone overlap possible
- lockscreen/fullscreen call UI still needs polish
- Android force-stop behavior may still be OS/vendor-dependent
