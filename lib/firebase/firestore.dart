import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDatabase {
  static final FirebaseFirestore instance = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> collection(
      String collectionPath) {
    return instance.collection(collectionPath);
  }

  static CollectionReference<T> collectionWithConverter<T>(
    String collectionPath, {
    required T Function(
            DocumentSnapshot<Map<String, dynamic>>, SnapshotOptions?)
        fromFirestore,
    required Map<String, Object?> Function(T, SetOptions?) toFirestore,
  }) {
    return instance.collection(collectionPath).withConverter<T>(
          fromFirestore: fromFirestore,
          toFirestore: toFirestore,
        );
  }

  // static addUsers(
  //     {required String path,
  //     required String docID,
  //     required String nim,
  //     required Map<String, dynamic> data,
  //     required Future<void> Function() onSuccess,
  //     required FutureOr<Null> Function(Object?, StackTrace)
  //         handleError}) async {
  //   await _instance.runTransaction((transaction) async {
  //     CollectionReference<Map<String, dynamic>> ref =
  //         _instance.collection(path);
  //     Query<Map<String, dynamic>> query = ref.where(
  //       "info.nim",
  //       isEqualTo: nim,
  //     );
  //     QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

  //     if (snapshot.docs.isEmpty) {
  //       print("Data tidak ditemukan");
  //       transaction.set(ref.doc(docID), data);
  //     } else {
  //       print("Data ditemukan");
  //     }
  //   }).onError((error, stackTrace) => handleError(error, stackTrace));
  // }
}
