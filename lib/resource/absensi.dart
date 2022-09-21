class Absensi {
  int? id;
  String? idMahasiswa;
  String? userID;
  String? docID;
  int? masuk;
  int? keluar;
  String? status;
  String? kodeMK;

  Map<String, Object?> toFirestoreMap() {
    var map = <String, Object?>{
      "docID": docID,
      "userID": userID,
      "masuk": masuk,
      "keluar": keluar,
      "status": status,
      "kodeMK": kodeMK,
    };

    return map;
  }

  Absensi();

  Absensi.fromFirestore(Map<String, Object?> map, String id) {
    docID = id;
    userID = map["userID"] as String?;
    masuk = map["masuk"] as int?;
    keluar = map["keluar"] as int?;
    status = map["status"] as String?;
    kodeMK = map["kodeMK"] as String?;
  }
}
