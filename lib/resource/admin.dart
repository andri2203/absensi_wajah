import 'package:sqflite/sqflite.dart';

import 'database/database.dart';

class TableAdmin {
  final String table = "tb_admin";
  final String id = "id";
  final String username = "username";
  final String password = "password";

  Database? _db;

  Future<void> _onCreate(Database database, int version) async {
    await database.execute('''
    create table $table (
      $id integer primary key autoincrement,
      $username text not null,
      $password text not null,
    )
    ''');
  }

  TableAdmin() {
    if (_db == null) {
      DatabaseInstance(onCreate: _onCreate).database().then((database) {
        _db = database;
        _setDefaultAdminAccount(_db!);
      }).catchError((err) {
        // ignore: avoid_print
        print(err);
      });
    }
  }

  Future<void> _setDefaultAdminAccount(Database db) async {
    String accountDefault = "admin1234";
    Map<String, Object?> account = {
      username: accountDefault,
      password: accountDefault,
    };
    Admin? adminAccount = await login(accountDefault, accountDefault);

    if (adminAccount == null) {
      await add(Admin.fromMap(account));
    }
  }

  Future<Admin?> add(Admin admin) async {
    if (_db == null) return null;
    admin.id = await _db?.insert(table, admin.toMap());
    return admin;
  }

  Future<Admin?> login(String u, String p) async {
    if (_db == null) return null;

    List<Map<String, Object?>>? maps = [];

    maps = await _db?.query(
      table,
      columns: [id, username, password],
      where: "$username = ? AND $password = ?",
      whereArgs: [u, p],
    );

    if (maps != null) {
      return Admin.fromMap(maps.first);
    }

    return null;
  }

  Future<Admin?> getAdminById(int adminID) async {
    if (_db == null) return null;

    List<Map<String, Object?>>? maps = [];

    maps = await _db?.query(
      table,
      columns: [id, username, password],
      where: "$id = ?",
      whereArgs: [adminID],
    );

    if (maps != null) {
      return Admin.fromMap(maps.first);
    }

    return null;
  }

  Future<List<Admin>?> getAllAdmin() async {
    if (_db == null) return null;

    List<Admin>? admins = <Admin>[];

    List<Map<String, Object?>>? maps = await _db?.query(
      table,
      columns: [id, username, password],
    );

    if (maps != null) {
      for (var i = 0; i < maps.length; i++) {
        admins.add(Admin.fromMap(maps[i]));
      }

      return admins;
    }

    return null;
  }
}

class Admin {
  int? id;
  String? username;
  String? password;

  final TableAdmin tbAdmin = TableAdmin();

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      tbAdmin.username: username,
      tbAdmin.password: password,
    };

    if (id != null) {
      map[tbAdmin.id] = id;
    }

    return map;
  }

  Admin();

  Admin.fromMap(Map<String, Object?> map) {
    id = map[tbAdmin.id] as int?;
    username = map[tbAdmin.username] as String?;
    password = map[tbAdmin.password] as String?;
  }
}
