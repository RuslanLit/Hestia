# Android Call Wake-Up Stable Checkpoint

Known working:
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
