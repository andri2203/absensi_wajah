import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;
import '../firebase/firestore.dart';
import '../resource/absensi.dart';
import '../resource/user_profile.dart';
import '../resource/mahasiswa.dart';
import '../firebase/auth_service.dart';
import '../utils/date_time.dart';
import '../utils/model.dart';
import '../utils/utils.dart';
import 'rekam_wajah.dart';

class MahasiswaPage extends StatefulWidget {
  const MahasiswaPage({Key? key, required this.user}) : super(key: key);

  final UserProfile user;

  @override
  State<MahasiswaPage> createState() => _MahasiswaPageState();
}

class _MahasiswaPageState extends State<MahasiswaPage>
    with SingleTickerProviderStateMixin {
  late UserProfile user;
  late Mahasiswa mahasiswa;
  GlobalKey<ScaffoldMessengerState> scaffold =
      GlobalKey<ScaffoldMessengerState>();
  GlobalKey<FormState> form = GlobalKey<FormState>();
  TextEditingController nim = TextEditingController();
  TextEditingController nama = TextEditingController();
  TextEditingController semester = TextEditingController();
  TextEditingController unit = TextEditingController();
  TextEditingController prodi = TextEditingController();

  CollectionReference<Map<String, dynamic>> refMataKuliah =
      FirestoreDatabase.collection("mataKuliah");
  CollectionReference<Map<String, dynamic>> refAbsensi =
      FirestoreDatabase.collection("absensi");

  int startEpochTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    0,
    0,
    0,
  ).millisecondsSinceEpoch;
  int endEpochTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
    59,
  ).millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    initUser();
  }

  initUser() {
    setState(() {
      user = widget.user;
      mahasiswa = Mahasiswa.fromFirestoreMap(user.uid!, user.info);
    });
  }

  handleUpdateProfile(BuildContext context) {
    Map<String, dynamic> data = {
      "name": nama.text,
      "info": {
        "dataWajah": mahasiswa.dataWajah,
        "foto": mahasiswa.foto,
        "nama": nama.text,
        "nim": nim.text,
        "prodi": prodi.text,
        "semester": semester.text,
        "unit": unit.text,
      }
    };
    FirestoreDatabase.collection("users")
        .doc(user.uid)
        .update(data)
        .then((value) {
      initUser();
      scaffold.currentState!.showSnackBar(const SnackBar(
        content: Text("Berhasil Merubah Profil"),
      ));
    }).catchError((error) {
      // ignore: use_build_context_synchronously
      scaffold.currentState!.showSnackBar(SnackBar(
        content: Text("Gagal Merubah Profil: $error"),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffold,
      child: Scaffold(
        appBar: AppBar(title: const Text("Mahasiswa"), actions: [
          IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Yakin ingin Keluar?"),
                      actions: [
                        TextButton(
                            child: const Text("Tidak"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            }),
                        TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await AuthService.singOut();
                            },
                            child: const Text("Ya")),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.logout))
        ]),
        body: Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              avatarWidget(),
              streamMataKuliah(),
            ],
          ),
        ),
      ),
    );
  }

  Widget streamMataKuliah() {
    return StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
      stream: refMataKuliah.snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.data == null || !snapshot.hasData) {
          return const Center(
            child: Text("Data Tidak Ditemukan."),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
            stream: refAbsensi
                .where("masuk", isGreaterThan: startEpochTime)
                .where("masuk", isLessThan: endEpochTime)
                .where("userID", isEqualTo: mahasiswa.uid)
                .orderBy("masuk", descending: true)
                .snapshots(includeMetadataChanges: true),
            builder: (context, snap2) {
              List<QueryDocumentSnapshot<Map<String, Object?>>> listMatkul =
                  snapshot.data == null ? [] : snapshot.data!.docs;
              List<QueryDocumentSnapshot<Map<String, Object?>>> listAbsensi =
                  snap2.data == null ? [] : snap2.data!.docs;
              Map<String, Absensi> mapAbsensi = {};
              for (var i = 0; i < listAbsensi.length; i++) {
                QueryDocumentSnapshot<Map<String, Object?>> dt = listAbsensi[i];
                Map<String, Object?> map = dt.data();
                mapAbsensi[map["kodeMK"].toString()] =
                    Absensi.fromFirestore(map, dt.id);
              }

              return Expanded(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      QueryDocumentSnapshot<Map<String, Object?>> doc =
                          listMatkul[index];
                      Map<String, Object?> dt = doc.data();
                      Map<String, dynamic> jamMasuk =
                          dt["jam_masuk"] as Map<String, dynamic>;
                      TimeOfDay jamWaktuMasuk = TimeOfDay(
                          hour: jamMasuk["jam"]!, minute: jamMasuk["menit"]!);
                      int dispensasi = dt["dispensasi"] as int;
                      DateTime now = DateTime.now();
                      TimeOfDay batas = jamWaktuMasuk.replacing(
                          minute: jamWaktuMasuk.minute + dispensasi);
                      DateTime jamDispensasi = DateTime(now.year, now.month,
                          now.day, batas.hour, batas.minute);
                      int perbedaanJam =
                          jamDispensasi.difference(now).inMinutes;

                      Absensi? absensi;
                      for (var kodeMK in mapAbsensi.keys) {
                        if (kodeMK == doc.id) {
                          absensi = mapAbsensi[kodeMK];
                        }
                      }

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            // crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black,
                                      )),
                                  Text(
                                    "${dt["matkul"].toString()} - ${jamWaktuMasuk.format(context)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    "Batas Absen $dispensasi Menit",
                                    style: const TextStyle(
                                        color: Colors.lightBlue),
                                  ),
                                  absensi == null
                                      ? Container()
                                      : Text(
                                          "Masuk ${dateTime(
                                            DateTime.fromMillisecondsSinceEpoch(
                                                absensi.masuk!),
                                          )}",
                                          style: const TextStyle(
                                              color: Colors.lightGreen),
                                        ),
                                  absensi == null
                                      ? Container()
                                      : Text(
                                          absensi.keluar != 0
                                              ? "Keluar ${dateTime(
                                                  DateTime
                                                      .fromMillisecondsSinceEpoch(
                                                          absensi.keluar!),
                                                )}"
                                              : "",
                                          style: TextStyle(
                                              color: Colors.redAccent[700]),
                                        ),
                                ],
                              ),
                              absensi == null
                                  ? perbedaanJam > 0
                                      ? ElevatedButton(
                                          onPressed: () {
                                            Absensi? dt;
                                            for (var kodeMK
                                                in mapAbsensi.keys) {
                                              if (mapAbsensi[kodeMK]!.keluar ==
                                                  0) {
                                                dt = mapAbsensi[kodeMK];
                                              }
                                            }

                                            if (dt == null) {
                                              handleAbsen(kodeMK: doc.id);
                                            } else {
                                              scaffold.currentState!
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Anda Harus Keluar dari Kelas ${mataKuliah(listMatkul, dt)} Dulu",
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text("Masuk"))
                                      : Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(10),
                                            ),
                                            border:
                                                Border.all(color: Colors.red),
                                          ),
                                          child: const Text(
                                            "Alpa",
                                            style: TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        )
                                  : absensi.keluar == 0
                                      ? ElevatedButton(
                                          onPressed: () => handleAbsen(
                                                absensi: absensi,
                                              ),
                                          child: const Text("Keluar"))
                                      : Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(10),
                                            ),
                                            border:
                                                Border.all(color: Colors.green),
                                          ),
                                          child: const Text(
                                            "Selesai",
                                            style: TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            });
      },
    );
  }

  Widget avatarWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            userImage(),
            userInfo(),
          ],
        ),
      ),
    );
  }

  Widget userInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.name!,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          "${mahasiswa.nim}/Semester ${mahasiswa.semester}",
          style: const TextStyle(
            color: Colors.black45,
            fontStyle: FontStyle.italic,
          ),
        ),
        Text(
          mahasiswa.prodi!,
          style: const TextStyle(
            color: Colors.black45,
            fontStyle: FontStyle.italic,
          ),
        ),
        Text(
          user.email!,
          style: const TextStyle(
            color: Colors.black45,
            fontStyle: FontStyle.italic,
          ),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.green.shade400),
          child: const Text("Edit Profil"),
          onPressed: () {
            setState(() {
              nim.text = mahasiswa.nim!;
              nama.text = mahasiswa.nama!;
              semester.text = mahasiswa.semester!;
              unit.text = mahasiswa.unit!;
              prodi.text = mahasiswa.prodi!;
            });
            showModalBottomSheet(
              context: context,
              builder: formBottomSheet,
            );
          },
        ),
      ],
    );
  }

  Widget userImage() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Image.network(
        width: 100,
        height: 100,
        mahasiswa.foto!,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(100),
            ),
            child: child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget formBottomSheet(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: form,
          child: Container(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
            child: Column(children: [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      handleUpdateProfile(context);
                    },
                    child: const Text("Ubah Profil"),
                  )
                ],
              ),
            ]),
          ),
        ),
      ),
    );
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

  Future<void> handleAbsen({Absensi? absensi, String kodeMK = ""}) async {
    final files = (await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const RekamWajah(),
      ),
    ));

    if (files != null) {
      imglib.Image? imageLoaded = await _loadImage(files);
      final image = InputImage.fromFile(files);
      final faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      bool res = false;
      Face face;
      List<Face> faces = await faceDetector.processImage(image);
      await Future.delayed(const Duration(milliseconds: 500));
      Interpreter? interp = await loadModel();

      if (mounted) {
        if (interp != null) {
          for (face in faces) {
            double x, y, w, h;
            x = (face.boundingBox.left - 10);
            y = (face.boundingBox.top - 10);
            w = (face.boundingBox.width + 10);
            h = (face.boundingBox.height + 10);
            imglib.Image croppedImage = imglib.copyCrop(
                imageLoaded!, x.round(), y.round(), w.round(), h.round());
            croppedImage = imglib.copyResizeCropSquare(croppedImage, 112);
            res = recog(croppedImage, interp);
          }

          if (res) {
            DateTime waktu = DateTime.now();
            if (absensi == null) {
              Map<String, dynamic> input = {
                "userID": mahasiswa.uid,
                "masuk": waktu.millisecondsSinceEpoch,
                "keluar": 0,
                "status": "masuk",
                "kodeMK": kodeMK,
              };

              refAbsensi.add(input).then((_) {
                scaffold.currentState!.showSnackBar(SnackBar(
                  content: Text(
                      "Anda Berhasil Masuk Kelas di waktu ${dateTime(waktu)}"),
                ));
              }).onError((error, _) {
                scaffold.currentState!.showSnackBar(SnackBar(
                  content: Text("Gagal: $error"),
                ));
              });
            } else {
              Map<String, dynamic> update = {
                "keluar": waktu.millisecondsSinceEpoch,
                "status": "keluar",
              };

              refAbsensi.doc(absensi.docID).update(update).then((_) {
                scaffold.currentState!.showSnackBar(SnackBar(
                  content: Text(
                      "Anda Sudah Keluar Kelas di waktu ${dateTime(waktu)}"),
                ));
              }).onError((error, _) {
                scaffold.currentState!.showSnackBar(SnackBar(
                  content: Text("Gagal: $error"),
                ));
              });
            }
          } else {
            scaffold.currentState!.showSnackBar(const SnackBar(
              content: Text("Wajah Tidak Dikenali"),
            ));
          }
        } else {
          scaffold.currentState!.showSnackBar(const SnackBar(
            content: Text("Modul Belum Berjalan, Silahkan Coba Lagi."),
          ));
        }
      }
    } else {
      scaffold.currentState!.showSnackBar(const SnackBar(
        content: Text("Proses Dibatalkan"),
      ));
    }
  }

  bool recog(imglib.Image img, Interpreter? interpreter) {
    if (interpreter != null) {
      List input = imageToByteListFloat32(img, 112, 128, 128);
      input = input.reshape([1, 112, 112, 3]);
      List output =
          List.filled(1 * 192, null, growable: false).reshape([1, 192]);
      interpreter.run(input, output);
      output = output.reshape([192]);
      return compare(List.from(output));
    }

    return false;
  }

  bool compare(List currEmb) {
    //mengembalikan nama pemilik akun
    double minDist = 999;
    double currDist = 0.0;
    double threshold = 1.0;

    currDist = euclideanDistance(mahasiswa.dataWajah!, currEmb);
    if (currDist <= threshold && currDist < minDist) {
      return true;
    }

    return false;
  }

  Future<imglib.Image?> _loadImage(File? file) async {
    if (file != null) {
      final data = await file.readAsBytes();
      return imglib.decodeImage(data);
    }

    return null;
  }

  String mataKuliah(
      List<QueryDocumentSnapshot<Map<String, Object?>>> listMatkul,
      Absensi absensi) {
    Map<String, Object?> map = {};

    for (var i = 0; i < listMatkul.length; i++) {
      QueryDocumentSnapshot<Map<String, Object?>> matkul = listMatkul[i];

      if (matkul.id == absensi.kodeMK) {
        map = matkul.data();
      }
    }

    return map["matkul"].toString();
  }
}
