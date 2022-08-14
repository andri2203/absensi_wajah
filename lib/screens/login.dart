import 'package:absensi_wajah/resource/admin.dart';
import 'package:absensi_wajah/screens/halaman_utama.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TableAdmin tableAdmin = TableAdmin();
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  bool secureText = true;
  bool isLoading = false;

  Future<void> handleLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (form.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      Admin? admin = await tableAdmin.login(username.text, password.text);

      if (mounted) {
        if (admin != null) {
          setState(() {
            isLoading = false;
          });
          await prefs.setInt("adminID", admin.id!);
          // ignore: use_build_context_synchronously
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => HalamanUtama(
              title: "Absensi",
              admin: admin,
            ),
          ));
        } else {
          setState(() {
            isLoading = false;
          });
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Gagal: Username / Password salah'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.white,
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Center(
                          child:
                              Image.asset("logo.png", width: 200, height: 200)),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: Text(
                          "Login Administrator".toUpperCase(),
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    textfield(context,
                        label: "Username",
                        controller: username,
                        icon: const Icon(Icons.person),
                        autoFocus: true),
                    textfield(context,
                        label: "Password",
                        controller: password,
                        icon: IconButton(
                          onPressed: () {
                            setState(() {
                              secureText = !secureText;
                            });
                          },
                          icon: Icon(secureText ? Icons.lock : Icons.lock_open),
                        ),
                        obsecureText: secureText),
                    ElevatedButton.icon(
                      onPressed: () => handleLogin(context),
                      icon: const Icon(Icons.login),
                      label: const Text("Masuk"),
                    ),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  color: Colors.black54.withOpacity(0.7),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget textfield(
    BuildContext context, {
    required String label,
    required Widget icon,
    required TextEditingController controller,
    bool obsecureText = false,
    bool autoFocus = false,
  }) {
    String? _errorText(String? text) {
      final validCharacters = RegExp(r'^[a-zA-Z0-9_\-=@,\.;]+$');

      if (text == null || text.isEmpty) {
        return "$label Tidak boleh kosong";
      }

      if (text.length < 5) {
        return "$label harus lebih dari 5 karakter";
      }

      if (validCharacters.hasMatch(text) == false) {
        return "$label harus berupa Huruf, Angka dan Tidak boleh spasi.";
      }

      return null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obsecureText,
        autofocus: autoFocus,
        validator: _errorText,
        decoration: InputDecoration(
          suffixIcon: icon,
          labelText: label,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
        ),
      ),
    );
  }
}
