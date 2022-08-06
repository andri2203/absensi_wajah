import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import "package:sqflite/sqflite.dart";

class DatabaseInstance {
  final String _dbName = "absensi.db";
  final int _dbVersion = 1;

  final Future<void> Function(Database)? onConfigure;
  final Future<void> Function(Database, int)? onCreate;
  final Future<void> Function(Database, int, int)? onUpgrade;
  final Future<void> Function(Database, int, int)? onDowngrade;
  final Future<void> Function(Database)? onOpen;

  Database? db;

  DatabaseInstance({
    this.onConfigure,
    this.onCreate,
    this.onUpgrade,
    this.onDowngrade,
    this.onOpen,
  });

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
        onConfigure: onConfigure,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onDowngrade: onDowngrade,
        onOpen: onOpen,
      );
    } on DatabaseException catch (_, e) {
      // ignore: avoid_print
      print('Error Database: ${_.result}');
      throw e;
    }
  }
}
