import 'package:absensi_wajah/resource/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static User? get user => _auth.currentUser;
  static DateTime? get lastSeen => _auth.currentUser!.metadata.lastSignInTime;
  static DateTime? get createAt => _auth.currentUser!.metadata.creationTime;

  static Future<void> updateEmail(
    String newemail,
    UserProfile userProfile,
  ) async {
    UserCredential credential = await user!.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: userProfile.email!,
        password: userProfile.password!,
      ),
    );

    return credential.user!.updateEmail(newemail);
  }

  static Future<void> updatePassword(
    String newPassword,
    UserProfile userProfile,
  ) async {
    UserCredential credential = await user!.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: userProfile.email!,
        password: userProfile.password!,
      ),
    );

    return credential.user!.updatePassword(newPassword);
  }

  static Future<User?> signIn(String email, String password,
      ScaffoldMessengerState scaffoldMessengerState) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      scaffoldMessengerState.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return null;
    }
  }

  static Future<User?> signUp(String email, String password,
      ScaffoldMessengerState scaffoldMessengerState) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      scaffoldMessengerState.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return null;
    }
  }

  static delete(
    String email,
    String password,
    ScaffoldMessengerState scaffoldMessengerState,
  ) async {
    try {
      if (_auth.currentUser == null) {
        scaffoldMessengerState.showSnackBar(
          const SnackBar(content: Text("Anda Belum Login")),
        );
        return;
      }
      User user = _auth.currentUser!;
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      UserCredential result =
          await user.reauthenticateWithCredential(credential);
      if (result.user != null) {
        await result.user!.delete();
      } else {
        scaffoldMessengerState.showSnackBar(
          const SnackBar(content: Text("Gagal memuat data user")),
        );
        return;
      }
    } catch (e) {
      scaffoldMessengerState.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }
  }

  static Future<void> singOut() async {
    _auth.signOut();
  }

  static Stream<User?> get firebaseUserStream => _auth.userChanges();
}
