# TODO: Android release build hang

Issue: Android release build hangs in Gradle `lintVitalAnalyzeRelease` / `minifyReleaseWithR8` area.

Observed on 2026-05-03 while running:

```powershell
flutter build apk --release -v --no-shrink --build-name=4.0.4-rc1 --build-number=5
```

Notes:
- Debug APK builds successfully.
- Release APK does not reach dexing, signing, or packaging.
- Last observed active Gradle tasks were Android lint vital analysis tasks, with `:app:minifyReleaseWithR8` also started despite `--no-shrink`.
