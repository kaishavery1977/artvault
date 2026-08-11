import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration.
///
/// NOTE: Replace the placeholder values below with values from your Firebase
/// console (Project settings → Your apps) before going to production:
///
/// ```sh
/// dart pub global activate flutterfire_cli
/// flutterfire configure
/// ```
///
/// The app is fully functional in offline mode without these values. When
/// present, cloud sync, backup and analytics light up automatically.
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
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQvFm_QowkvkhLL7IIwvutwPRzNsXF7_s',
    appId: '1:629393260589:android:0f6b3fb7133e15ddfdb8a4',
    messagingSenderId: '629393260589',
    projectId: 'artvault-d69d0',
    databaseURL: 'https://artvault-d69d0-default-rtdb.firebaseio.com',
    storageBucket: 'artvault-d69d0.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQsyEA0zPEqDkkOEpH5AJf2_8M-WceWRc',
    appId: '1:629393260589:ios:ce970c8ee54c9655fdb8a4',
    messagingSenderId: '629393260589',
    projectId: 'artvault-d69d0',
    databaseURL: 'https://artvault-d69d0-default-rtdb.firebaseio.com',
    storageBucket: 'artvault-d69d0.firebasestorage.app',
    iosClientId: '629393260589-fs8ind9q5gc52k64j2uip6rrkvjubp3v.apps.googleusercontent.com',
    iosBundleId: 'com.artvault.artvault',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAlEmaqwhaF9X49NX56Z5CtgznjYsa3r-Q',
    appId: '1:629393260589:web:c964a2dac4fad408fdb8a4',
    messagingSenderId: '629393260589',
    projectId: 'artvault-d69d0',
    authDomain: 'artvault-d69d0.firebaseapp.com',
    databaseURL: 'https://artvault-d69d0-default-rtdb.firebaseio.com',
    storageBucket: 'artvault-d69d0.firebasestorage.app',
    measurementId: 'G-RVQ6XBW3L0',
  );
}
