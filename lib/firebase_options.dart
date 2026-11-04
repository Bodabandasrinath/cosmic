import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Replace placeholder values with your actual Firebase project credentials.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web Firebase configuration

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBwKzzsDTH-BNZV02OxJbJIGDNrD6od2UY',
    appId: '1:320838985453:web:cd0a58b0a5ed9a5b48cee4',
    messagingSenderId: '320838985453',
    projectId: 'cosmic-ed916',
    authDomain: 'cosmic-ed916.firebaseapp.com',
    storageBucket: 'cosmic-ed916.firebasestorage.app',
    measurementId: 'G-NBYZDB73KC',
  );
  // Android Firebase configuration (fallback if google-services.json is not placed in android/app)

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPETFB_rphiJjjXlPrLQ59SBvKi6MS1ms',
    appId: '1:320838985453:android:e5d22410ef7a3e8a48cee4',
    messagingSenderId: '320838985453',
    projectId: 'cosmic-ed916',
    storageBucket: 'cosmic-ed916.firebasestorage.app',
  );
  // iOS configuration (optional)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_IOS_API_KEY',
    appId: 'REPLACE_WITH_YOUR_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.cosmic.chat',
  );
}
