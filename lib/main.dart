import 'package:absensi_wajah/resource/admin.dart';
import 'package:absensi_wajah/screens/halaman_utama.dart';
import 'package:absensi_wajah/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TableAdmin tableAdmin = TableAdmin();

  Future<Admin?>? cekLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? adminID = prefs.getInt("adminID");

    if (adminID == null) return null;

    final Admin? admin = await tableAdmin.getAdminById(adminID);

    if (admin != null) return admin;

    return null;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.focusedChild?.unfocus();
        }
      },
      child: GetMaterialApp(
        title: 'Absensi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
        ),
        home: FutureBuilder<Admin?>(
          future: cekLogin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done ||
                snapshot.connectionState == ConnectionState.active) {
              final Admin? admin = snapshot.data;

              if (admin == null) {
                return const Login();
              } else {
                return HalamanUtama(title: "Absensi", admin: admin);
              }
            }

            return const SizedBox(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
    );
  }
}
