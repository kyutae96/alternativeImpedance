/// Firebase configuration options for Alternative Impedance
/// Auto-generated based on google-services.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD1hQQ1r5p8fQ5p8Q1r5p8fQ5p8Q1r5p8f',
    appId: '1:584860542748:web:a724e5eb8972a400a53cd9',
    messagingSenderId: '584860542748',
    projectId: 'artificialcochleadev',
    authDomain: 'artificialcochleadev.firebaseapp.com',
    databaseURL: 'https://artificialcochleadev-default-rtdb.firebaseio.com',
    storageBucket: 'artificialcochleadev.firebasestorage.app',
  );

  // Android configuration (from google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD1hQQ1r5p8fQ5p8Q1r5p8fQ5p8Q1r5p8f',
    appId: '1:584860542748:android:a724e5eb8972a400a53cd9',
    messagingSenderId: '584860542748',
    projectId: 'artificialcochleadev',
    databaseURL: 'https://artificialcochleadev-default-rtdb.firebaseio.com',
    storageBucket: 'artificialcochleadev.firebasestorage.app',
  );

  // iOS configuration (placeholder)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD1hQQ1r5p8fQ5p8Q1r5p8fQ5p8Q1r5p8f',
    appId: '1:584860542748:ios:a724e5eb8972a400a53cd9',
    messagingSenderId: '584860542748',
    projectId: 'artificialcochleadev',
    databaseURL: 'https://artificialcochleadev-default-rtdb.firebaseio.com',
    storageBucket: 'artificialcochleadev.firebasestorage.app',
    iosBundleId: 'com.todoc.alternativeImpedance',
  );

  // macOS configuration (placeholder)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD1hQQ1r5p8fQ5p8Q1r5p8fQ5p8Q1r5p8f',
    appId: '1:584860542748:macos:a724e5eb8972a400a53cd9',
    messagingSenderId: '584860542748',
    projectId: 'artificialcochleadev',
    databaseURL: 'https://artificialcochleadev-default-rtdb.firebaseio.com',
    storageBucket: 'artificialcochleadev.firebasestorage.app',
    iosBundleId: 'com.todoc.alternativeImpedance',
  );

  // Windows configuration (placeholder)
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD1hQQ1r5p8fQ5p8Q1r5p8fQ5p8Q1r5p8f',
    appId: '1:584860542748:windows:a724e5eb8972a400a53cd9',
    messagingSenderId: '584860542748',
    projectId: 'artificialcochleadev',
    databaseURL: 'https://artificialcochleadev-default-rtdb.firebaseio.com',
    storageBucket: 'artificialcochleadev.firebasestorage.app',
  );

  // Linux configuration (placeholder)
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyD1hQQ1r5p8fQ5p8Q1r5p8fQ5p8Q1r5p8f',
    appId: '1:584860542748:linux:a724e5eb8972a400a53cd9',
    messagingSenderId: '584860542748',
    projectId: 'artificialcochleadev',
    databaseURL: 'https://artificialcochleadev-default-rtdb.firebaseio.com',
    storageBucket: 'artificialcochleadev.firebasestorage.app',
  );
}
