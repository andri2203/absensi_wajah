enum UserRole {
  admin,
  mahasiswa,
}

class UserProfile {
  String? uid;
  String? name;
  String? email;
  String? password;
  String? role;
  bool isSuper = false;
  dynamic info;

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      "name": name,
      "email": email,
      "password": password,
      "role": role,
      "info": info,
    };

    return map;
  }

  UserProfile();

  UserProfile.fromMap(String userID, Map<String, dynamic> map) {
    uid = userID;
    name = map["name"];
    email = map["email"];
    password = map["password"];
    role = map["role"];
    info = map["info"];
    if (map["role"] == "admin") {
      isSuper = map["isSuper"];
    }
  }
}
