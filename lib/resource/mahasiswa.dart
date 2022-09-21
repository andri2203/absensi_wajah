class Mahasiswa {
  int? id;
  String? uid;
  String? nim;
  String? nama;
  String? semester;
  String? unit;
  String? prodi;
  String? foto;
  List<dynamic>? dataWajah;

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      "uid": uid,
      "nim": nim,
      "nama": nama,
      "semester": semester,
      "unit": unit,
      "prodi": prodi,
      "foto": foto,
      "dataWajah": dataWajah,
    };

    return map;
  }

  Mahasiswa();

  Mahasiswa.fromFirestoreMap(String userID, Map<String, Object?> map) {
    uid = userID;
    nim = map["nim"] as String?;
    nama = map["nama"] as String?;
    semester = map["semester"] as String?;
    unit = map["unit"] as String?;
    prodi = map["prodi"] as String?;
    foto = map["foto"] as String?;
    dataWajah = map["dataWajah"] as List<dynamic>;
  }
}
