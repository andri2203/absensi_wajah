import 'package:sqflite/sqflite.dart';
import 'database/database.dart';

class TableAbsensi {
  final String table = "tb_absensi";
  final String id = "id";
  final String idMahasiswa = "id_mahasiswa";
  final String masuk = "masuk";
  final String keluar = "keluar";
  final String status = "status";
  final String kodeMK = "kode_mk";

  Future<Database> database() {
    return DatabaseInstance().database();
  }

  TableAbsensi();

  Future<Absensi?> add(Absensi absensi) async {
    Database db = await database();
    absensi.id = await db.insert(table, absensi.toMap());
    return absensi;
  }

  Future<List<Absensi?>> get() async {
    Database db = await database();
    List<Map<String, Object?>> maps = [];
    List<Absensi?> data = [];

    maps = await db.query(
      table,
      columns: [id, idMahasiswa, masuk, keluar, status, kodeMK],
      orderBy: "$masuk DESC",
    );

    for (var i = 0; i < maps.length; i++) {
      data.add(Absensi.fromMap(maps[i]));
    }

    return data;
  }

  Future<List<Absensi?>> getOneDayOnly(int start, int end) async {
    Database db = await database();
    List<Map<String, Object?>> maps = [];
    List<Absensi?> data = [];

    maps = await db.query(
      table,
      columns: [id, idMahasiswa, masuk, keluar, status, kodeMK],
      where: "$masuk > ? AND $masuk < ?",
      whereArgs: [start, end],
      orderBy: "$masuk DESC",
    );

    for (var i = 0; i < maps.length; i++) {
      data.add(Absensi.fromMap(maps[i]));
    }

    return data;
  }

  Future<List<Absensi?>> getById(int idAbsensi) async {
    Database db = await database();
    List<Map<String, Object?>> maps = [];
    List<Absensi?> data = [];

    maps = await db.query(
      table,
      columns: [id, idMahasiswa, masuk, keluar, status, kodeMK],
      where: "$id = ?",
      whereArgs: [idAbsensi],
    );

    for (var i = 0; i < maps.length; i++) {
      data.add(Absensi.fromMap(maps[i]));
    }

    return data;
  }

  Future<List<Absensi?>> getByIdMahasiswa(int idMhs) async {
    Database db = await database();
    List<Map<String, Object?>> maps = [];
    List<Absensi?> data = [];

    maps = await db.query(
      table,
      columns: [id, idMahasiswa, masuk, keluar, status, kodeMK],
      where: "$idMahasiswa = ?",
      whereArgs: [idMhs],
    );

    for (var i = 0; i < maps.length; i++) {
      data.add(Absensi.fromMap(maps[i]));
    }

    return data;
  }

  Future<int> update(Absensi absensi) async {
    Database db = await database();

    return await db.update(
      table,
      absensi.toMap(),
      where: "$id = ?",
      whereArgs: [absensi.id],
    );
  }

  Future<Absensi?> delete(int id) async {
    return null;
  }
}

class Absensi {
  int? id;
  String? idMahasiswa;
  int? masuk;
  int? keluar;
  String? status;
  String? kodeMK;

  final TableAbsensi tbAbsensi = TableAbsensi();

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      tbAbsensi.id: id,
      tbAbsensi.idMahasiswa: idMahasiswa,
      tbAbsensi.masuk: masuk,
      tbAbsensi.keluar: keluar,
      tbAbsensi.status: status,
      tbAbsensi.kodeMK: kodeMK,
    };

    if (id != null) {
      map[tbAbsensi.id] = id;
    }

    return map;
  }

  Absensi();

  Absensi.fromMap(Map<String, Object?> map) {
    id = map[tbAbsensi.id] as int?;
    idMahasiswa = map[tbAbsensi.idMahasiswa] as String?;
    masuk = map[tbAbsensi.masuk] as int?;
    keluar = map[tbAbsensi.keluar] as int?;
    status = map[tbAbsensi.status] as String?;
    kodeMK = map[tbAbsensi.kodeMK] as String?;
  }
}
