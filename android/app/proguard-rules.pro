# Keep Flutter plugin entry points, manifest-discovered Android components,
# and call/push-related integrations stable while R8 shrinks app code/resources.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.example.hestia.** { *; }

# WebRTC and JNI rules are also supplied by flutter_webrtc, but keeping them
# here makes the app-level release profile explicit.
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-keep class org.jni_zero.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# Firebase Messaging and local notification callbacks may be reached by Android
# framework or generated plugin code.
-keep class com.google.firebase.messaging.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.work.** { *; }

-dontwarn org.webrtc.**
-dontwarn org.jni_zero.**

# Flutter references Play Core deferred components even when this APK release
# flow does not use Play Store dynamic feature delivery.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
