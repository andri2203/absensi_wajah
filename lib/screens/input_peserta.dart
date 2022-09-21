import 'dart:async';
import 'dart:io';

import 'package:absensi_wajah/resource/mahasiswa.dart';
import 'package:absensi_wajah/screens/rekam_wajah.dart';
import 'package:absensi_wajah/utils/model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiver/collection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore.dart';
import '../utils/utils.dart';

class InputPeserta extends StatefulWidget {
  const InputPeserta({Key? key}) : super(key: key);

  @override
  State<InputPeserta> createState() => _InputPesertaState();
}

class _InputPesertaState extends State<InputPeserta>
    with SingleTickerProviderStateMixin {
  List<Mahasiswa?> mahasiswa = [];
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController nim = TextEditingController();
  final TextEditingController nama = TextEditingController();
  final TextEditingController semester = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController prodi = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  File? imageFile;
  Size imageSize = const Size(0, 0);
  List? e1;
  dynamic data = {};
  String _predRes = "";
  double threshold = 1.0;
  bool _verify = false;
  dynamic scanResult;
  late File jsonFile;
  Directory? tempDir;
  late AnimationController controller;
  bool isCreateData = false;
  bool isLoading = false;
  Mahasiswa? peserta;
  String? userID;

  GlobalKey<ScaffoldMessengerState> scaffold =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    ambilDataWajah();
    controller = AnimationController(vsync: this);
  }

  ambilDataWajah() async {
    final snapshot = await FirestoreDatabase.collection("users")
        .where("role", isEqualTo: "mahasiswa")
        .get();
    final dataWajah = snapshot.docs.map((e) {
      Map<String, Object?> map = {e.id: e.data()["info"]["dataWajah"]};
      return map;
    }).toList();
    Map<String, dynamic> maps = {};

    for (var item in dataWajah) {
      maps[item.keys.first] = item[item.keys.first];
    }

    data = maps;
  }

  handleRekamWajah() async {
    File? file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) {
        return const RekamWajah();
      }),
    );

    if (file != null) {
      // initJsonFile();
      ambilDataWajah();
      setState(() {
        isLoading = true;
      });
      String res;
      Face face;
      final bytesFile = await file.readAsBytes();
      imglib.Image? image = imglib.decodeImage(bytesFile);
      final inputImage = InputImage.fromFile(file);
      final faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
      ));
      dynamic finalResult = Multimap<String, Face>();
      List<Face> faces = await faceDetector.processImage(inputImage);
      await Future.delayed(const Duration(milliseconds: 500));
      Interpreter? interpreter = await loadModel();

      if (mounted) {
        if (interpreter != null) {
          String? response;
          for (face in faces) {
            double x, y, w, h;
            x = (face.boundingBox.left - 10);
            y = (face.boundingBox.top - 10);
            w = (face.boundingBox.width + 10);
            h = (face.boundingBox.height + 10);
            imglib.Image croppedImage = imglib.copyCrop(
                image!, x.round(), y.round(), w.round(), h.round());
            croppedImage = imglib.copyResizeCropSquare(croppedImage, 112);
            res = recog(interpreter, croppedImage);
            response = res;
            finalResult.add(res, face);
          }

          if (response != null) {
            interpreter.close();
            if (response == "Tidak dikenali") {
              setState(() {
                imageFile = file;
                imageSize =
                    Size(image!.width.toDouble(), image.height.toDouble());
                scanResult = finalResult;
                isLoading = false;
              });

              // ignore: use_build_context_synchronously
              scaffold.currentState!.showSnackBar(const SnackBar(
                  content:
                      Text("Wajah Tidak Dikenal. Silahkan Tambah Mahasiswa")));
            } else {
              DocumentSnapshot<Map<String, Object?>> qry =
                  await FirestoreDatabase.collection("users")
                      .doc(response)
                      .get();
              Mahasiswa mhs = Mahasiswa.fromFirestoreMap(
                  qry.id, qry.data()!["info"] as Map<String, Object?>);
              setState(() {
                imageFile = null;
                peserta = mhs;
                nim.text = mhs.nim!;
                nama.text = mhs.nama!;
                semester.text = mhs.semester!;
                unit.text = mhs.unit!;
                prodi.text = mhs.prodi!;
                isLoading = false;
                userID = mhs.uid;
              });
              // ignore: use_build_context_synchronously
              scaffold.currentState!.showSnackBar(const SnackBar(
                content: Text(
                    "Wajah Di Dikenal. Silahkan Ubah Data. Jika Diperlukan."),
              ));
            }
          } else {
            interpreter.close();
            // ignore: use_build_context_synchronously
            scaffold.currentState!.showSnackBar(const SnackBar(
                content:
                    Text("Tidak ada wajah di gambar. Silahkan Foto Ulang")));
          }
        }
      }
    }
  }

  Future<String> getPath() async {
    Directory? dir = await getExternalStorageDirectory();
    return dir!.path;
  }

  Future<File> moveFile(File sourceFile, String newPath) async {
    final newFile = await sourceFile.copy(newPath);
    return newFile;
  }

  simpanData() {
    var storageRef = FirebaseStorage.instance.ref();
    if (form.currentState!.validate() && e1 != null) {
      FirestoreDatabase.instance.runTransaction((transaction) async {
        CollectionReference<Map<String, dynamic>> ref =
            FirestoreDatabase.instance.collection("users");
        Query<Map<String, dynamic>> query = ref.where(
          "info.nim",
          isEqualTo: nim.text,
        );
        QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

        if (snapshot.docs.isNotEmpty) {
          scaffold.currentState!.showSnackBar(const SnackBar(
            content: Text("NIM yang anda gunakan telah terdaftar"),
          ));

          return;
        }

        var fotoMahasiswa = storageRef.child("foto/${nim.text}.jpg");
        await fotoMahasiswa.putFile(imageFile!);
        var lokasiFoto = await fotoMahasiswa.getDownloadURL();

        try {
          User? user = await AuthService.signUp(
            email.text,
            password.text,
            scaffold.currentState!,
          );

          if (user == null) {
            scaffold.currentState!.showSnackBar(const SnackBar(
              content: Text("Gagal Menambah Data"),
            ));

            return;
          }

          Map<String, Object?> maps = {
            "name": nama.text,
            "email": email.text,
            "password": password.text,
            "role": "mahasiswa",
            "info": {
              "nim": nim.text,
              "nama": nama.text,
              "semester": semester.text,
              "unit": unit.text,
              "prodi": prodi.text,
              "foto": lokasiFoto,
              "dataWajah": e1,
            },
          };

          transaction.set(ref.doc(user.uid), maps);

          setState(() {
            isCreateData = false;
            imageFile = null;
            e1 = null;
            nim.text = '';
            nama.text = '';
            semester.text = '';
            unit.text = '';
            prodi.text = '';
          });

          scaffold.currentState!.showSnackBar(SnackBar(
            content: Text(
                "Akun Mahasiswa Berhasil Ditambahkan. Anda akan diarahkan ke akun ${user.email}"),
          ));

          if (mounted) {
            Navigator.of(context).pop();
          }
        } catch (error) {
          if (mounted) {
            AuthService.delete(
                email.text, password.text, scaffold.currentState!);

            scaffold.currentState!.showSnackBar(SnackBar(
              content: Text("Gagal Auth: $error"),
            ));
          }
        }
      }).catchError((error) {
        scaffold.currentState!.showSnackBar(SnackBar(
          content: Text("Gagal Transaction: $error"),
        ));
      });
    } else {
      // ignore: use_build_context_synchronously
      scaffold.currentState!.showSnackBar(const SnackBar(
          content: Text("Mohon Periksa Field dan Gambar Wajah")));
    }
  }

  handleUpdateData() async {
    if (form.currentState!.validate()) {
      FirestoreDatabase.instance.runTransaction((transaction) async {
        CollectionReference<Map<String, dynamic>> userRef =
            FirestoreDatabase.collection("users");

        Query<Map<String, dynamic>> query = userRef.where(
          "info.nim",
          isEqualTo: nim.text,
        );

        QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

        if (snapshot.docs.isNotEmpty) {
          scaffold.currentState!.showSnackBar(const SnackBar(
            content: Text("NIM yang anda gunakan telah terdaftar"),
          ));

          return;
        }

        Map<String, Object?> map = {
          "name": nama.text,
          "info": {
            "nim": nim.text,
            "nama": nama.text,
            "semester": semester.text,
            "unit": unit.text,
            "prodi": prodi.text,
            "foto": peserta!.foto,
            "dataWajah": peserta!.dataWajah,
          },
        };

        transaction.update(userRef.doc(userID), map);

        setState(() {
          isCreateData = false;
          imageFile = null;
          peserta = null;
          nim.text = '';
          nama.text = '';
          semester.text = '';
          unit.text = '';
          prodi.text = '';
        });
        scaffold.currentState!.showSnackBar(
            const SnackBar(content: Text("Data Berhasil Di Ubah")));
      }).catchError((error) {
        scaffold.currentState!.showSnackBar(
            SnackBar(content: Text("Data gagal Di Ubah. $error")));
      });
    }
  }

  String recog(Interpreter interpreter, imglib.Image img) {
    List input = imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List output = List.filled(1 * 192, null, growable: false).reshape([1, 192]);
    interpreter.run(input, output);
    output = output.reshape([192]);
    setState(() {
      e1 = List.from(output);
    });
    return compare(e1!);
  }

  String compare(List currEmb) {
    //mengembalikan nama pemilik akun
    double minDist = 999;
    double currDist = 0.0;
    _predRes = "Tidak dikenali";
    for (String label in data.keys) {
      currDist = euclideanDistance(data[label], currEmb);
      if (currDist <= threshold && currDist < minDist) {
        minDist = currDist;
        _predRes = label;
        if (_verify == false) {
          setState(() {
            _verify = true;
          });
        }
      }
    }
    return _predRes;
  }

  Widget textField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    // Validator
    bool notNull = true,
    bool regexNoSpace = false,
    int minLengthValues = 5,
    bool obsecureText = false,
  }) {
    String? validator(String? text) {
      final regexNoSpacing = RegExp(r'^[a-zA-Z0-9_\-=@,\.;]+$');

      if (notNull && text == null || text!.isEmpty) {
        return "$label Tidak Boleh Kosong";
      }

      if (text.length < minLengthValues) {
        return "Jumlah Karakter $label harus lebih dari $minLengthValues";
      }

      if (regexNoSpace && regexNoSpacing.hasMatch(text)) {
        return "Karakter $label harus berupa Huruf, Angka dan tidak ada Spasi.";
      }

      return null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 5, 0, 5),
      child: TextFormField(
        obscureText: obsecureText,
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          label: Text(label),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffold,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Data Mahasiswa"),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isCreateData ? showForm(context) : showData(context),
        ),
        floatingActionButton: !isCreateData
            ? ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Tambah Mahasiswa"),
                onPressed: () {
                  setState(() {
                    peserta = null;
                    isCreateData = !isCreateData;
                  });
                },
              )
            : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Kembali"),
                  onPressed: () async {
                    setState(() {
                      peserta = null;
                      isCreateData = !isCreateData;
                      imageFile = null;
                      e1 = null;
                      nim.text = '';
                      nama.text = '';
                      semester.text = '';
                      unit.text = '';
                      prodi.text = '';
                      userID = null;
                    });
                  },
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: Icon(peserta == null ? Icons.save : Icons.edit),
                  label: Text(peserta == null ? "Simpan" : "Ubah"),
                  onPressed: peserta == null ? simpanData : handleUpdateData,
                ),
              ]),
      ),
    );
  }

  Widget showForm(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: form,
          child: Column(
            children: [
              if (imageFile != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: Image.file(
                      imageFile!,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
              if (peserta != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: Image.network(peserta!.foto!,
                        fit: BoxFit.fitWidth, width: 50),
                  ),
                ),
              if (peserta == null)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: handleRekamWajah,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Rekam Wajah"),
                  ),
                ),
              textField(
                controller: nim,
                label: "Nim",
                keyboardType: const TextInputType.numberWithOptions(),
              ),
              textField(controller: nama, label: "Nama"),
              textField(
                  controller: semester,
                  label: "Semester",
                  keyboardType: const TextInputType.numberWithOptions(),
                  minLengthValues: 1),
              textField(controller: unit, label: "Unit"),
              textField(controller: prodi, label: "Prodi"),
              if (peserta == null)
                textField(
                  controller: email,
                  label: "Email",
                  keyboardType: TextInputType.emailAddress,
                ),
              if (peserta == null)
                textField(
                    controller: password,
                    label: "Password",
                    obsecureText: true),
            ],
          ),
        ),
      ),
    );
  }

  Column showData(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 15, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Text(
            "Data Mahasiswa Absensi",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 5),
        ),
        Expanded(
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            padding:
                const EdgeInsets.only(bottom: 10, left: 10, right: 10, top: 5),
            child: dataStreamBuilder(),
          ),
        ),
      ],
    );
  }

  Widget dataStreamBuilder() {
    return StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
      stream: FirestoreDatabase.collection("users")
          .where("role", isEqualTo: "mahasiswa")
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("Data Tidak Ditemukan."),
          );
        }

        return ListView(
          children: snapshot.data!.docs
              .map((DocumentSnapshot<Map<String, Object?>> document) {
            Mahasiswa mhs = Mahasiswa.fromFirestoreMap(
                document.id, document.data()!["info"] as Map<String, Object?>);
            return dataList(context, mhs);
          }).toList(),
        );
      },
    );
  }

  Card dataList(BuildContext context, Mahasiswa? mhs) {
    return Card(
      child: ListTile(
        title: Text("${mhs!.nama}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mhs.nim!),
            Text("Semester ${mhs.semester} / Unit ${mhs.unit}"),
            Text("${mhs.prodi}"),
          ],
        ),
        leading: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: 50,
            height: 50,
            child: mhs.foto != null
                ? Image.network(mhs.foto!, fit: BoxFit.fitWidth)
                : Image.asset("person.png", fit: BoxFit.fitWidth),
          ),
        ),
        trailing: IconButton(
            onPressed: () {
              setState(() {
                isCreateData = true;
                peserta = mhs;
                nim.text = mhs.nim!;
                nama.text = mhs.nama!;
                semester.text = mhs.semester!;
                unit.text = mhs.unit!;
                prodi.text = mhs.prodi!;
                userID = mhs.uid;
              });
            },
            icon: const Icon(
              Icons.edit,
              color: Colors.green,
            )),
      ),
    );
  }
}
