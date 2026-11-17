import 'package:firebase_core/firebase_core.dart';

/// Web client configuration for the Firebase project `booqora-infidec`.
/// These values are public identifiers (not secrets); access is enforced by
/// Firestore / Storage security rules.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBBhhtkioiioS6rjSR6ajkVe5fYko_09lI',
    appId: '1:366716320328:web:5f6e271867def9a82cb67d',
    messagingSenderId: '366716320328',
    projectId: 'booqora-infidec',
    authDomain: 'booqora-infidec.firebaseapp.com',
    storageBucket: 'booqora-infidec.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => web;
}
