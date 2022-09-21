import 'package:absensi_wajah/firebase/auth_service.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  GlobalKey<ScaffoldMessengerState> scaffold =
      GlobalKey<ScaffoldMessengerState>();
  bool secureText = true;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffold,
      child: Scaffold(
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
                            child: Image.asset("logo.png",
                                width: 200, height: 200)),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Center(
                          child: Text(
                            "Login Absensi Wajah".toUpperCase(),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      textfield(context,
                          label: "Email",
                          controller: username,
                          icon: const Icon(Icons.person),
                          keyboardType: TextInputType.emailAddress,
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
                            icon:
                                Icon(secureText ? Icons.lock : Icons.lock_open),
                          ),
                          obsecureText: secureText),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await AuthService.signIn(username.text, password.text,
                              scaffold.currentState!);
                        },
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
      ),
    );
  }

  Widget textfield(BuildContext context,
      {required String label,
      required Widget icon,
      required TextEditingController controller,
      bool obsecureText = false,
      bool autoFocus = false,
      TextInputType? keyboardType}) {
    String? errorText(String? text) {
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
        validator: errorText,
        keyboardType: keyboardType,
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
