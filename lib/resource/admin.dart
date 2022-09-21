class Admin {
  String? id;
  String? username;
  String? password;

  Admin();

  Admin.fromMap(Map<String, Object?> map) {
    id = map["id"] as String?;
    username = map["username"] as String?;
    password = map["password"] as String?;
  }
}
