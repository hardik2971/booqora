import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client configuration for project `booqora-infidec`
/// (public identifiers — access is enforced by security rules).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyCxM7wdnth7r8HC_2KiZHskiHk5FTpE1YA',
    appId: '1:366716320328:android:283d56f92756710a2cb67d',
    messagingSenderId: '366716320328',
    projectId: 'booqora-infidec',
    storageBucket: 'booqora-infidec.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCwIPTNJxJq4SDNEjS_imwAU4wCPB_vVWY',
    appId: '1:366716320328:ios:db0dd930e4ff895e2cb67d',
    messagingSenderId: '366716320328',
    projectId: 'booqora-infidec',
    storageBucket: 'booqora-infidec.firebasestorage.app',
    iosBundleId: 'io.booqora.booqoraMobile',
  );

  /// Used only when the mobile UI is previewed in a browser (QA).
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBBhhtkioiioS6rjSR6ajkVe5fYko_09lI',
    appId: '1:366716320328:web:5f6e271867def9a82cb67d',
    messagingSenderId: '366716320328',
    projectId: 'booqora-infidec',
    authDomain: 'booqora-infidec.firebaseapp.com',
    storageBucket: 'booqora-infidec.firebasestorage.app',
  );
}
