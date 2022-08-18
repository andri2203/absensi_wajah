import 'package:absensi_wajah/resource/admin.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AkunAdmin extends StatefulWidget {
  const AkunAdmin({Key? key}) : super(key: key);

  @override
  State<AkunAdmin> createState() => _AkunAdminState();
}

class _AkunAdminState extends State<AkunAdmin> {
  TableAdmin tableAdmin = TableAdmin();
  String userSuperAdmin = "admin1234";
  Admin? admin;
  GlobalKey<FormState> form = GlobalKey<FormState>();
  TextEditingController username = TextEditingController();
  TextEditingController password = TextEditingController();
  bool secureText = true;
  bool isUpdate = false;
  int id = 0;

  @override
  void initState() {
    super.initState();
    getCurrentAdmin();
  }

  Future<Admin?> addAdmin() async {
    if (form.currentState!.validate()) {
      Map<String, Object?> map = {
        tableAdmin.username: username.text,
        tableAdmin.password: password.text,
      };

      Admin? acc = await tableAdmin.add(Admin.fromMap(map));

      return acc;
    }
    return null;
  }

  Future<int> updateAdmin() async {
    if (form.currentState!.validate()) {
      Map<String, Object?> map = {
        tableAdmin.id: id,
        tableAdmin.username: username.text,
        tableAdmin.password: password.text,
      };

      int updated = await tableAdmin.update(Admin.fromMap(map));
      return updated;
    }
    return 0;
  }

  Future<int> deleteAdmin(int idAdmin) async {
    int deleted = await tableAdmin.delete(idAdmin);
    return deleted;
  }

  Future<void> getCurrentAdmin() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    final int? adminID = pref.getInt("adminID");
    Admin? account = await tableAdmin.getAdminById(adminID!);

    if (mounted) {
      setState(() {
        admin = account;
        if (account!.username != userSuperAdmin) {
          id = account.id!.toInt();
          username.text = account.username!;
          password.text = account.password!;
          secureText = false;
        }
      });
    }
  }

  // Hanya Super Admin Yang Dapat Akses Semua Data Admin dan Input Admin Baru.
  Future<List<Admin>?> getAllAdmin() async {
    List<Admin>? list = [];

    list = await tableAdmin.getAllAdmin();

    return list;
  }

  String? _errorText(String? text) {
    final validCharacters = RegExp(r'^[a-zA-Z0-9_\-=@,\.;]+$');

    if (text == null || text.isEmpty) {
      return "Tidak boleh kosong";
    }

    if (text.length < 5) {
      return "Harus lebih dari 5 karakter";
    }

    if (validCharacters.hasMatch(text) == false) {
      return "Harus berupa Huruf, Angka dan Tidak boleh spasi.";
    }

    return null;
  }

  Widget superAdminWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: const [
          Text("Tambah Admin Baru"),
        ]),
        const Divider(
          color: Colors.black54,
          height: 20,
        ),
        Form(
          key: form,
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: TextFormField(
                  controller: username,
                  validator: _errorText,
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.person),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    labelText: "Username",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: TextFormField(
                controller: password,
                obscureText: secureText,
                validator: _errorText,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        secureText = !secureText;
                      });
                    },
                    icon: Icon(secureText ? Icons.lock : Icons.lock_open),
                  ),
                  labelText: "Password",
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                ),
              ),
            ),
          ]),
        ),
        isUpdate == false
            ? ElevatedButton.icon(
                onPressed: () async {
                  Admin? added = await addAdmin();
                  if (added != null) {
                    setState(() {
                      isUpdate = false;
                      id = 0;
                      username.text = '';
                      password.text = '';
                      secureText = true;
                    });
                    getAllAdmin();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Berhasil Menambah User Admin Baru"),
                    ));
                  } else {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Gagal Menambah User Admin Baru"),
                    ));
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text("Tambah"))
            : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        isUpdate = false;
                        id = 0;
                        username.text = '';
                        password.text = '';
                        secureText = true;
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Batal")),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                    onPressed: () async {
                      int updated = await updateAdmin();
                      if (updated > 0) {
                        setState(() {
                          isUpdate = false;
                          id = 0;
                          username.text = '';
                          password.text = '';
                          secureText = true;
                        });
                        getAllAdmin();
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text("Berhasil Mengubah Data Admin"),
                        ));
                      } else {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text("Gagal Mengubah Data Admin"),
                        ));
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"))
              ]),
        const Divider(
          color: Colors.black54,
          height: 10,
        ),
        Expanded(
            child: FutureBuilder<List<Admin>?>(
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.none) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.data == null) {
              return Container();
            }

            return ListView.builder(
              itemBuilder: (context, index) {
                Admin acc = snapshot.data![index];
                return Card(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    width: MediaQuery.of(context).size.width,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text.rich(TextSpan(children: [
                              const WidgetSpan(child: Icon(Icons.person)),
                              TextSpan(text: " : ${acc.username}"),
                            ])),
                            Text.rich(TextSpan(children: [
                              const WidgetSpan(child: Icon(Icons.key)),
                              TextSpan(text: " : ${acc.password}"),
                            ])),
                          ],
                        ),
                        if (acc.username != userSuperAdmin)
                          const SizedBox(height: 10),
                        if (acc.username != userSuperAdmin)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      isUpdate = true;
                                      id = acc.id!.toInt();
                                      username.text = acc.username!;
                                      password.text = acc.password!;
                                      secureText = false;
                                    });
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          "Mohon Teliti Saat Mengubah Username dan Password"),
                                    ));
                                  },
                                  icon: const Icon(Icons.edit),
                                  color: Colors.green,
                                ),
                                IconButton(
                                  onPressed: () {
                                    showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                              title: Text(
                                                  "Yakin Hapus User ${acc.username}?"),
                                              content: const Text(
                                                  "User ini akan di hapus secara permanen. Yakin ingin dihapus?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(ctx).pop();
                                                  },
                                                  child: const Text("Tidak",
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.of(ctx).pop();
                                                    int deleted =
                                                        await deleteAdmin(
                                                            acc.id!.toInt());
                                                    if (deleted > 0) {
                                                      setState(() {
                                                        id = 0;
                                                      });
                                                      getAllAdmin();
                                                      // ignore: use_build_context_synchronously
                                                      ScaffoldMessenger.of(ctx)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  "User Admin ${acc.username} telah dihapus.")));
                                                    } else {
                                                      // ignore: use_build_context_synchronously
                                                      ScaffoldMessenger.of(ctx)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  "User Admin ${acc.username} gagal dihapus.")));
                                                    }
                                                  },
                                                  child: const Text("Ya",
                                                      style: TextStyle(
                                                          color: Colors.green)),
                                                ),
                                              ],
                                            ));
                                  },
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                ),
                              ]),
                      ],
                    ),
                  ),
                );
              },
              itemCount: snapshot.data!.length,
            );
          },
          future: getAllAdmin(),
        ))
      ]),
    );
  }

  Future<int> updateUserAdmin() async {
    Map<String, Object?> map = {
      tableAdmin.id: id,
      tableAdmin.username: username.text,
      tableAdmin.password: password.text,
    };

    int updated = await tableAdmin.update(Admin.fromMap(map));
    return updated;
  }

  Widget adminWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Form(
        key: form,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              child: Text("Selamat Datang, ${admin!.username}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                controller: username,
                enabled: isUpdate,
                validator: _errorText,
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.person),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  labelText: "Username",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                controller: password,
                obscureText: secureText,
                validator: _errorText,
                enabled: isUpdate,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        secureText = !secureText;
                      });
                    },
                    icon: Icon(secureText ? Icons.lock : Icons.lock_open),
                  ),
                  labelText: "Password",
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isUpdate = !isUpdate;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isUpdate
                            ? "Membuka Akses Update"
                            : "Menutup Akses Update"),
                      ));
                    },
                    child: Text(
                        isUpdate ? "Tutup Akses Update" : "Buka Akses Update")),
                ElevatedButton.icon(
                    onPressed: () async {
                      if (isUpdate == true) {
                        if (username.text == admin!.username &&
                                password.text != admin!.password ||
                            username.text != admin!.username &&
                                password.text == admin!.password) {
                          int updated = await updateUserAdmin();
                          if (updated > 0) {
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop<String>("logout");
                          } else {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text("Gagal Mengubah Data Admin"),
                            ));
                          }
                        } else {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text("Tidak Ada Data yang diubah"),
                          ));
                        }
                      } else {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text("Akses update tertutup"),
                        ));
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"))
              ],
            ),
          ],
        ),
      ),
    );
  }

  cekAdminLevel(BuildContext context) {
    if (admin != null) {
      if (admin!.username == userSuperAdmin) {
        return superAdminWidget(context);
      } else {
        return adminWidget(context);
      }
    } else {
      getCurrentAdmin();
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Akun Admin"),
      ),
      body: cekAdminLevel(context),
    );
  }
}
