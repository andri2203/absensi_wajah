import 'package:flutter/material.dart';

class AkunAdmin extends StatefulWidget {
  const AkunAdmin({Key? key}) : super(key: key);

  @override
  State<AkunAdmin> createState() => _AkunAdminState();
}

class _AkunAdminState extends State<AkunAdmin> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Akun Admin"),
      ),
      body: const Text("Halaman Akun Admin"),
    );
  }
}
