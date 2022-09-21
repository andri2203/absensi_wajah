import 'package:absensi_wajah/firebase/firestore.dart';
import 'package:absensi_wajah/resource/user_profile.dart';
import 'package:absensi_wajah/screens/login.dart';
import 'package:absensi_wajah/screens/mahasiswa.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/halaman_utama.dart';

class Middleware extends StatelessWidget {
  const Middleware({Key? key}) : super(key: key);

  Future<UserProfile?> getUserProfile(String uid) async {
    CollectionReference<UserProfile> userRef =
        FirestoreDatabase.collectionWithConverter<UserProfile>(
      "users",
      fromFirestore: (snapshot, _) =>
          UserProfile.fromMap(uid, snapshot.data()!),
      toFirestore: (userprofile, _) => userprofile.toMap(),
    );

    UserProfile? userProfile = await userRef
        .doc(uid)
        .get()
        .then<UserProfile?>((snapshot) => snapshot.data());

    return userProfile;
  }

  @override
  Widget build(BuildContext context) {
    User? user = Provider.of<User?>(context);
    if (user == null) {
      return const Login();
    }

    return FutureBuilder<UserProfile?>(
      future: getUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData) {
          return const Login();
        }

        UserProfile userProfile = snapshot.data!;

        if (userProfile.role == "admin") {
          return HalamanUtama(user: userProfile);
        } else {
          return MahasiswaPage(user: userProfile);
        }
      },
    );
  }
}
