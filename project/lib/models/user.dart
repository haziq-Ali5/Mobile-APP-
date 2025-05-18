import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class AppUser {
  final String uid;
  final String email;

  AppUser({required this.uid, required this.email});

  factory AppUser.fromFirebase(firebase_auth.User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '', // Handle potential null email (adjust as needed)
    );
  }
}