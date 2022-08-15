import 'package:sqflite/sqflite.dart';
import 'database/database.dart';

class TableMahasiswa {
  final String table = "tb_mahasiswa";
  final String id = "id";
  final String nim = "nim";
  final String nama = "nama";
  final String semester = "semester";
  final String unit = "unit";
  final String prodi = "prodi";
  final String foto = "foto";

  Future<Database> database() {
    return DatabaseInstance().database();
  }

  TableMahasiswa();

  Future<Mahasiswa?> add(Mahasiswa mahasiswa) async {
    Database db = await database();
    mahasiswa.id = await db.insert(table, mahasiswa.toMap());
    return mahasiswa;
  }

  Future<List<Mahasiswa?>?> get() async {
    Database db = await database();

    List<Map<String, Object?>>? maps = [];
    List<Mahasiswa?>? data = [];

    maps = await db.query(
      table,
      columns: [id, nim, nama, semester, unit, prodi, foto],
    );

    for (var i = 0; i < maps.length; i++) {
      data.add(Mahasiswa.fromMap(maps[i]));
    }

    return data;
  }

  Future<Mahasiswa?> getById(int mahasiswaID) async {
    Database db = await database();
    List<Map<String, Object?>>? maps = [];

    maps = await db.query(
      table,
      columns: [id, nim, nama, semester, unit, prodi, foto],
      where: "id = ?",
      whereArgs: [mahasiswaID],
    );
    return Mahasiswa.fromMap(maps.first);
  }

  Future<Mahasiswa?> getByNim(String nimMahasiswa) async {
    Database db = await database();
    List<Map<String, Object?>>? maps = [];

    maps = await db.query(
      table,
      columns: [id, nim, nama, semester, unit, prodi, foto],
      where: "nim = ?",
      whereArgs: [nimMahasiswa],
    );

    return Mahasiswa.fromMap(maps.first);
  }

  Future<int> update(Mahasiswa mahasiswa) async {
    Database db = await database();

    return await db.update(
      table,
      mahasiswa.toMap(),
      where: "$id = ?",
      whereArgs: [mahasiswa.id],
    );
  }

  Future<Mahasiswa?> delete(Mahasiswa mahasiswa) async {
    return null;
  }
}

class Mahasiswa {
  int? id;
  String? nim;
  String? nama;
  String? semester;
  String? unit;
  String? prodi;
  String? foto;

  final TableMahasiswa tbMahasiswa = TableMahasiswa();

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      tbMahasiswa.nim: nim,
      tbMahasiswa.nama: nama,
      tbMahasiswa.semester: semester,
      tbMahasiswa.unit: unit,
      tbMahasiswa.prodi: prodi,
      tbMahasiswa.foto: foto,
    };

    if (id != null) {
      map[tbMahasiswa.id] = id;
    }

    return map;
  }

  Mahasiswa();

  Mahasiswa.fromMap(Map<String, Object?> map) {
    id = map[tbMahasiswa.id] as int?;
    nim = map[tbMahasiswa.nim] as String?;
    nama = map[tbMahasiswa.nama] as String?;
    semester = map[tbMahasiswa.semester] as String?;
    unit = map[tbMahasiswa.unit] as String?;
    prodi = map[tbMahasiswa.prodi] as String?;
    foto = map[tbMahasiswa.foto] as String?;
  }
}
