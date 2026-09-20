import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDAhfL8hMAavhlEqYOzfUHTTYNlHIfv29k',
    appId: '1:327197406923:web:3d725bc2cd9164116f8d4e',
    messagingSenderId: '327197406923',
    projectId: 'connectcall-01',
    authDomain: 'connectcall-01.firebaseapp.com',
    storageBucket: 'connectcall-01.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDAhfL8hMAavhlEqYOzfUHTTYNlHIfv29k',
    appId: '1:327197406923:android:3d725bc2cd9164116f8d4e',
    messagingSenderId: '327197406923',
    projectId: 'connectcall-01',
    storageBucket: 'connectcall-01.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDAhfL8hMAavhlEqYOzfUHTTYNlHIfv29k',
    appId: '1:327197406923:ios:3d725bc2cd9164116f8d4e',
    messagingSenderId: '327197406923',
    projectId: 'connectcall-01',
    storageBucket: 'connectcall-01.firebasestorage.app',
  );
}
