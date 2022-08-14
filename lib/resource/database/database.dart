import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import "package:sqflite/sqflite.dart";

class DatabaseInstance {
  final String _dbName = "absensi.db";
  final int _dbVersion = 1;

  Database? db;

  DatabaseInstance();

  Future<Database> database() async {
    if (db != null) return db!;
    db = await _initDatabase();
    return db!;
  }

  Future<Database?> _initDatabase() async {
    try {
      Directory dir = await getApplicationDocumentsDirectory();
      String path = join(dir.path, _dbName);
      return openDatabase(
        path,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          Batch batch = db.batch();
          batch.execute('''
          create table tb_admin (
            id integer primary key autoincrement,
            username text not null,
            password text not null
          )
          ''');
          batch.execute('''
          create table tb_mahasiswa (
            id integer primary key autoincrement,
            nim text not null,
            nama text not null,
            semester text not null,
            unit text not null,
            prodi text not null,
            foto text not null
          )''');
          batch.execute('''
          create table tb_absensi (
            id integer primary key autoincrement,
            id_mahasiswa text not null,
            masuk int not null,
            keluar int not null,
            status text not null,
            kode_mk text not null,
            FOREIGN KEY(id_mahasiswa) REFERENCES tb_mahasiswa(id)
          )''');
          await batch.commit();
        },
      );
    } on DatabaseException catch (_, e) {
      // ignore: avoid_print
      print('Error Database: ${_.result}');
      throw e;
    }
  }
}
