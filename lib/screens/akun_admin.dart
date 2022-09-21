import 'package:absensi_wajah/firebase/auth_service.dart';
import 'package:absensi_wajah/resource/user_profile.dart';
import 'package:absensi_wajah/utils/date_time.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';

import '../firebase/firestore.dart';

class AkunAdmin extends StatefulWidget {
  const AkunAdmin({Key? key, required this.user}) : super(key: key);

  final UserProfile user;

  @override
  State<AkunAdmin> createState() => _AkunAdminState();
}

class _AkunAdminState extends State<AkunAdmin> with TickerProviderStateMixin {
  GlobalKey<FormState> formGantiPassword = GlobalKey<FormState>();
  AuthService auth = AuthService();
  UserProfile get user => widget.user;
  set user(UserProfile userProfile) {
    setState(() {
      user = userProfile;
    });
  }

  DateTime? get lastSignIn => AuthService.lastSeen;
  DateTime? get createAt => AuthService.createAt;
  final GlobalKey<ScaffoldMessengerState> scaffold =
      GlobalKey<ScaffoldMessengerState>();
  late TabController tabController;
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController passwordLama = TextEditingController();
  final TextEditingController passwordBaru = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();
  int tabIndex = 0;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: user.isSuper ? 3 : 2, vsync: this);
    tabController.addListener(() {
      setState(() {
        tabIndex = tabController.index;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    Size size = mediaQueryData.size;
    double widthCard = size.width - 16;

    return ScaffoldMessenger(
      key: scaffold,
      child: DefaultTabController(
        length: user.isSuper ? 3 : 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Akun Admin"),
          ),
          floatingActionButton: tabIndex == 2
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const TambahAdminbaru(),
                    ));
                  },
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: Container(
            color: Colors.deepOrange,
            child: TabBar(
              controller: tabController,
              tabs: [
                const Tab(
                  icon: Icon(Icons.edit),
                  text: "Edit Profil",
                ),
                const Tab(
                  icon: Icon(Icons.password),
                  text: "Ubah Password",
                ),
                if (user.isSuper)
                  const Tab(
                    icon: Icon(Icons.list),
                    text: "List Admin",
                  ),
              ],
            ),
          ),
          body: Container(
            width: size.width,
            height: size.height,
            padding: const EdgeInsets.all(8),
            color: Colors.white38,
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    width: widthCard,
                    child: Column(
                      children: [
                        Text(
                          user.name!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.email!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          user.isSuper ? "Super Admin" : "Admin",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Text(
                          lastSignIn == null
                              ? ""
                              : "Terakhir Login: ${dateTime(lastSignIn!)}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: tabController,
                    children: [
                      EditProfil(
                        mainContext: context,
                        name: name,
                        email: email,
                        user: user,
                        auth: auth,
                        onChangeUser: (userProfile) {
                          setState(() {
                            user = userProfile;
                          });
                        },
                        scaffold: scaffold,
                      ),
                      GantiPassword(
                        user: user,
                        scaffold: scaffold,
                        confirmPassword: confirmPassword,
                        mainContext: context,
                        passwordLama: passwordLama,
                        passwordBaru: passwordBaru,
                        form: formGantiPassword,
                      ),
                      if (user.isSuper)
                        ListAdmin(
                          user: user,
                          scaffold: scaffold,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditProfil extends StatelessWidget {
  final UserProfile user;
  final Function(UserProfile userProfile) onChangeUser;
  final AuthService auth;
  final BuildContext mainContext;
  final GlobalKey<ScaffoldMessengerState> scaffold;
  final TextEditingController name;
  final TextEditingController email;

  String get nameField => user.name!;
  String get emailField => user.email!;

  set nameField(String newName) {
    nameField = newName == "" ? user.name! : newName;
  }

  set emailField(String newEmail) {
    emailField = newEmail == "" ? user.email! : newEmail;
  }

  const EditProfil({
    super.key,
    required this.user,
    required this.onChangeUser,
    required this.scaffold,
    required this.auth,
    required this.name,
    required this.email,
    required this.mainContext,
  });

  handleUpdateData() async {
    if (name.text != "" || email.text != "") {
      Map<String, dynamic> map = {
        "name": name.text == "" ? user.name : name.text,
        "email": email.text == "" ? user.email : email.text,
      };

      DocumentReference<Map<String, dynamic>> docRef =
          FirestoreDatabase.collection("users").doc(user.uid);

      final WriteBatch batch = FirestoreDatabase.instance.batch();

      batch.update(docRef, map);

      if (email.text != "" && user.email != email.text) {
        if (!EmailValidator.validate(email.text)) {
          scaffold.currentState!.showSnackBar(const SnackBar(
            content: Text("Mohon Masukkan Email yang sah"),
          ));
          return;
        }
        AuthService.updateEmail(email.text, user).then((_) {
          batch.commit().then((_) {
            scaffold.currentState!.showSnackBar(SnackBar(
              content: Text(
                  "Berhasil mengubah ${user.name == name.text ? 'Email' : 'Email dan Nama'}. Anda akan logout dalam 4 detik."),
            ));
            Future.delayed(const Duration(seconds: 4)).then((_) {
              Navigator.of(mainContext).pop();
              AuthService.singOut();
            });
          }).catchError((error) {
            scaffold.currentState!.showSnackBar(SnackBar(
              content: Text(error.toString()),
            ));
          });
        }).catchError((error) {
          scaffold.currentState!.showSnackBar(SnackBar(
            content: Text(error.toString()),
          ));
        });
      } else {
        batch.commit().then((_) {
          scaffold.currentState!.showSnackBar(const SnackBar(
            content: Text("Berhasil mengubah data Admin"),
          ));
          Future.delayed(const Duration(seconds: 2)).then((_) {
            Navigator.of(mainContext).pop();
            AuthService.user!.reload();
          });
        }).catchError((error) {
          scaffold.currentState!.showSnackBar(SnackBar(
            content: Text(error.toString()),
          ));
        });
      }
    } else {
      scaffold.currentState!.showSnackBar(const SnackBar(
        content: Text("Tidak Ada Data yang diubah."),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        TextFormField(
          controller: name,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(label: Text("Nama")),
        ),
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(label: Text("Email")),
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: handleUpdateData,
              child: const Text("Edit Profil"),
            ),
          ],
        )
      ]),
    );
  }
}

class GantiPassword extends StatelessWidget {
  const GantiPassword({
    super.key,
    required this.user,
    required this.scaffold,
    required this.mainContext,
    required this.passwordBaru,
    required this.confirmPassword,
    required this.form,
    required this.passwordLama,
  });
  final UserProfile user;
  final BuildContext mainContext;
  final GlobalKey<ScaffoldMessengerState> scaffold;
  final GlobalKey<FormState> form;
  final TextEditingController passwordBaru;
  final TextEditingController passwordLama;
  final TextEditingController confirmPassword;

  Future<void> handleUbahPassword() async {
    if (form.currentState!.validate()) {
      AuthService.updatePassword(confirmPassword.text, user).then((_) {
        FirestoreDatabase.collection("users")
            .doc(user.uid)
            .update({"password": confirmPassword.text}).then((_) {
          scaffold.currentState!.showSnackBar(const SnackBar(
            content: Text(
                "Password Berhasil diubah. Anda akan logout dalam 4 detik."),
          ));
          Future.delayed(const Duration(seconds: 4)).then((_) {
            Navigator.of(mainContext).pop();
            AuthService.singOut();
          });
        }).catchError((error) {
          scaffold.currentState!.showSnackBar(SnackBar(
            content: Text(error.toString()),
          ));
        });
      }).catchError((error) {
        scaffold.currentState!.showSnackBar(SnackBar(
          content: Text(error.toString()),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(8),
      child: Form(
        key: form,
        child: Column(children: [
          TextFormField(
            controller: passwordLama,
            obscureText: true,
            decoration: const InputDecoration(label: Text("Password Lama")),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Tidak Boleh Kosong";
              }

              if (value.length < 6) {
                return "Password harus berisi minimal 6 karakter";
              }

              if (value != user.password) {
                return "Password Lama Tidak Sesuai";
              }

              return null;
            },
          ),
          TextFormField(
            controller: passwordBaru,
            obscureText: true,
            decoration: const InputDecoration(label: Text("Password Baru")),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Tidak Boleh Kosong";
              }

              if (value.length < 6) {
                return "Password harus berisi minimal 6 karakter";
              }
              if (value == passwordLama.text) {
                return "Password Baru tidak boleh sama dengan Password Lama";
              }

              return null;
            },
          ),
          TextFormField(
            controller: confirmPassword,
            obscureText: true,
            decoration:
                const InputDecoration(label: Text("Konfirmasi Password")),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Tidak Boleh Kosong";
              }

              if (value != passwordBaru.text) {
                return "Password tidak sesuai";
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: handleUbahPassword,
                child: const Text("Ganti Password"),
              ),
            ],
          )
        ]),
      ),
    );
  }
}

class ListAdmin extends StatelessWidget {
  const ListAdmin({
    super.key,
    required this.scaffold,
    required this.user,
  });
  final GlobalKey<ScaffoldMessengerState> scaffold;
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(8),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreDatabase.collection("users")
            .where("role", isEqualTo: "admin")
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Belum ada Admin baru"),
            );
          }
          List<QueryDocumentSnapshot<Map<String, dynamic>>> data =
              snapshot.data!.docs;
          List<UserProfile> usersAdmin = data
              .map((user) => UserProfile.fromMap(user.id, user.data()))
              .toList();
          return ListView.builder(
            itemCount: usersAdmin.length,
            itemBuilder: (context, index) {
              UserProfile userProfile = usersAdmin[index];

              return Card(
                child: ListTile(
                  title: Text(
                    userProfile.name!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: user.uid == userProfile.uid
                          ? Colors.lightGreen
                          : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "${userProfile.email}, (${userProfile.isSuper ? 'Super Admin' : 'Admin'})",
                    style: const TextStyle(
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  onTap: user.uid == userProfile.uid
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                content: Text(
                                    "Jadikan ${userProfile.name} sebagai ${userProfile.isSuper ? 'Super Admin' : 'Admin'}"),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      "batal",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      FirestoreDatabase.instance.runTransaction(
                                        (transaction) async {
                                          DocumentReference<
                                                  Map<String, dynamic>> docRef =
                                              FirestoreDatabase.collection(
                                                      "users")
                                                  .doc(userProfile.uid);

                                          DocumentSnapshot<Map<String, dynamic>>
                                              snap = await docRef.get();
                                          UserProfile currUser =
                                              UserProfile.fromMap(
                                            snap.id,
                                            snap.data()!,
                                          );

                                          transaction.update(docRef, {
                                            "isSuper": !currUser.isSuper,
                                          });
                                          scaffold.currentState!
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                "${userProfile.name} Sekarang adalah ${userProfile.isSuper ? 'Super Admin' : 'Admin'}"),
                                          ));
                                          Future.delayed(
                                                  const Duration(seconds: 2))
                                              .then((_) {
                                            Navigator.of(context).pop();
                                          });
                                        },
                                      ).catchError((error) {
                                        scaffold.currentState!
                                            .showSnackBar(SnackBar(
                                          content: Text(error.toString()),
                                        ));
                                      });
                                    },
                                    child: const Text(
                                      "Ya",
                                      style:
                                          TextStyle(color: Colors.lightGreen),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TambahAdminbaru extends StatefulWidget {
  const TambahAdminbaru({super.key});

  @override
  State<TambahAdminbaru> createState() => _TambahAdminbaruState();
}

class _TambahAdminbaruState extends State<TambahAdminbaru> {
  final GlobalKey<ScaffoldMessengerState> scaffold =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();
  bool isChecked = false;

  Color getColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffold,
      child: Scaffold(
        appBar: AppBar(title: const Text("Tambah Admin Baru")),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Map<String, dynamic> map = {
                "name": name.text,
                "email": email.text,
                "password": confirmPassword.text,
                "role": "admin",
                "isSuper": isChecked,
              };

              AuthService.signUp(
                email.text,
                confirmPassword.text,
                scaffold.currentState!,
              ).then((User? value) {
                if (value != null) {
                  FirestoreDatabase.collection("users")
                      .doc(value.uid)
                      .set(map)
                      .then((_) {
                    scaffold.currentState!.showSnackBar(SnackBar(
                      content: Text(
                          "Akun Admin Baru Berhasil Ditambahkan. Anda akan diarahkan ke akun ${email.text}"),
                    ));
                    Future.delayed(const Duration(seconds: 4)).then((_) {
                      Navigator.of(context).pop();
                    });
                  }).catchError((error) {
                    scaffold.currentState!.showSnackBar(SnackBar(
                      content: Text(error.toString()),
                    ));
                  });
                }
              }).catchError((error) {
                scaffold.currentState!.showSnackBar(SnackBar(
                  content: Text(error.toString()),
                ));
              });
            }
          },
          child: const Icon(Icons.add),
        ),
        body: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(8),
          child: Form(
              key: form,
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(label: Text("Nama")),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Nama Tidak Boleh Kosong";
                      }

                      return null;
                    },
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(label: Text("Email")),
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Email Tidak Boleh Kosong";
                      }

                      if (!EmailValidator.validate(value)) {
                        return "Email yang di input tidak sah";
                      }

                      return null;
                    },
                  ),
                  TextFormField(
                    obscureText: true,
                    controller: password,
                    decoration: const InputDecoration(label: Text("Password")),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Tidak Boleh Kosong";
                      }

                      if (value.length < 6) {
                        return "Password harus berisi minimal 6 karakter";
                      }

                      return null;
                    },
                  ),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                        label: Text("Konfirmasi Password")),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Tidak Boleh Kosong";
                      }

                      if (value != password.text) {
                        return "Password tidak sesuai";
                      }

                      return null;
                    },
                  ),
                  CheckboxListTile(
                    title: const Text("Super Admin"),
                    secondary: const Icon(Icons.check),
                    value: isChecked,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setState(() {
                        isChecked = value!;
                      });
                    },
                  )
                ],
              )),
        ),
      ),
    );
  }
}
