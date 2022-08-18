import 'package:sqflite/sqflite.dart';
import 'database/database.dart';

class TableAdmin {
  final String table = "tb_admin";
  final String id = "id";
  final String username = "username";
  final String password = "password";

  Future<Database> database() {
    return DatabaseInstance().database();
  }

  TableAdmin();

  Future<Admin?> _setDefaultAdminAccount(Database db) async {
    String accountDefault = "admin1234";
    Map<String, Object?> account = {
      username: accountDefault,
      password: accountDefault,
    };
    Admin? adminAccount = await login(accountDefault, accountDefault);

    if (adminAccount == null) {
      return await add(Admin.fromMap(account));
    }

    return adminAccount;
  }

  Future<Admin?> add(Admin admin) async {
    Database db = await database();

    admin.id = await db.insert(table, admin.toMap());
    return admin;
  }

  Future<Admin?> login(String u, String p) async {
    Database db = await database();

    List<Map<String, Object?>>? maps = [];

    maps = await db.query(
      table,
      columns: [id, username, password],
      where: "$username = ? AND $password = ?",
      whereArgs: [u, p],
    );

    if (maps.isNotEmpty) {
      return Admin.fromMap(maps.first);
    }

    if (username == "admin1234" && password == "admin1234") {
      return await _setDefaultAdminAccount(db);
    }

    return null;
  }

  Future<Admin?> getAdminById(int adminID) async {
    Database db = await database();

    List<Map<String, Object?>>? maps = [];

    maps = await db.query(
      table,
      columns: [id, username, password],
      where: "$id = ?",
      whereArgs: [adminID],
    );

    return Admin.fromMap(maps.first);
  }

  Future<List<Admin>?> getAllAdmin() async {
    Database db = await database();

    List<Admin>? admins = <Admin>[];

    List<Map<String, Object?>>? maps = await db.query(
      table,
      columns: [id, username, password],
    );

    for (var i = 0; i < maps.length; i++) {
      admins.add(Admin.fromMap(maps[i]));
    }

    return admins;
  }

  Future<int> update(Admin admin) async {
    Database db = await database();

    return await db.update(
      table,
      admin.toMap(),
      where: "$id = ?",
      whereArgs: [admin.id],
    );
  }

  Future<int> delete(int idAdmin) async {
    Database db = await database();

    return await db.delete(
      table,
      where: "$id = ?",
      whereArgs: [idAdmin],
    );
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
