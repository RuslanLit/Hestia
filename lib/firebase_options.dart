import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError('Firebase is configured for Android only.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAIZ6IvybaTwnp6tOuy3Be2om_QEsKPZrk',
    appId: '1:356417459997:android:bcefba18f1d3a3270ff3f4',
    messagingSenderId: '356417459997',
    projectId: 'hestia-b1543',
    storageBucket: 'hestia-b1543.firebasestorage.app',
  );
}
