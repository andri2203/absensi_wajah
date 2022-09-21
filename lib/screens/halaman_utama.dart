import 'dart:io';

import 'package:absensi_wajah/resource/user_profile.dart';
import 'package:absensi_wajah/screens/mata_kuliah.dart';
import 'package:absensi_wajah/utils/date_time.dart';
import 'package:absensi_wajah/resource/absensi.dart';
import 'package:absensi_wajah/resource/mahasiswa.dart';
import 'package:absensi_wajah/screens/input_peserta.dart';
import 'package:absensi_wajah/screens/laporan.dart';
import 'package:absensi_wajah/screens/presensi.dart';
import 'package:absensi_wajah/screens/rekam_wajah.dart';
import 'package:absensi_wajah/utils/model.dart';
import 'package:absensi_wajah/utils/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:quiver/collection.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../firebase/auth_service.dart';
import '../firebase/firestore.dart';
import 'akun_admin.dart';

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({Key? key, required this.user}) : super(key: key);

  final UserProfile user;

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  UserProfile get user => widget.user;
  File? imageFile;
  Size imageSize = const Size(0, 0);
  dynamic scanResult;
  Map<String, Mahasiswa> dataMahasiswa = {};
  List<Absensi?> dtAbsensi = [];
  bool isLoading = false;
  late Mahasiswa mahasiswa;
  Absensi? absensi;
  late int waktu;

  String mk = "pilih";

  List? e1;
  Interpreter? interpreter;
  String _predRes = "";
  dynamic data = {};
  double threshold = 1.0;
  bool _verify = false;
  String? respon;
  late File jsonFile;
  Directory? tempDir;
  bool isDetected = false;

  CollectionReference<Map<String, dynamic>> refMataKuliah =
      FirestoreDatabase.collection("mataKuliah");
  CollectionReference<Map<String, dynamic>> refAbsensi =
      FirestoreDatabase.collection("absensi");

  final GlobalKey<ScaffoldMessengerState> snackbar =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController nim = TextEditingController();
  final TextEditingController nama = TextEditingController();
  final TextEditingController semester = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController prodi = TextEditingController();
  final TextEditingController kdAbsen = TextEditingController();
  final TextEditingController kdMK = TextEditingController();
  String statusAbsensi = "masuk";
  String? seacrh;

  @override
  void initState() {
    super.initState();
  }

  String recog(imglib.Image img, List<Map<String, Mahasiswa>> mhs) {
    if (interpreter != null) {
      List input = imageToByteListFloat32(img, 112, 128, 128);
      input = input.reshape([1, 112, 112, 3]);
      List output =
          List.filled(1 * 192, null, growable: false).reshape([1, 192]);
      interpreter!.run(input, output);
      output = output.reshape([192]);
      setState(() {
        e1 = List.from(output);
      });
      return compare(e1!, mhs);
    }

    return "Terjadi Kesalahan.";
  }

  String compare(List currEmb, List<Map<String, Mahasiswa>> mhs) {
    //mengembalikan nama pemilik akun
    double minDist = 999;
    double currDist = 0.0;
    _predRes = "Tidak dikenali";
    for (var i = 0; i < mhs.length; i++) {
      Map<String, Mahasiswa> dtMHS = mhs[i];
      for (String label in dtMHS.keys) {
        currDist = euclideanDistance(dtMHS[label]!.dataWajah!, currEmb);
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
    }

    return _predRes;
  }

  Future<void> handleAbsenMasuk(
    BuildContext context,
    String? status, {
    List<QueryDocumentSnapshot<Map<String, Object?>>>? dataMhs,
    List<QueryDocumentSnapshot<Map<String, Object?>>>? dataAbsensi,
  }) async {
    if (mk == "pilih") {
      // ignore: use_build_context_synchronously
      snackbar.currentState!.showSnackBar(
          const SnackBar(content: Text("Silahan Pilih Mata Kuliah")));
      return;
    }
    setState(() {
      imageFile = null;
      e1 = null;
      interpreter = null;
      kdAbsen.text = '';
      kdMK.text = mk;
      nim.text = '';
      nama.text = '';
      semester.text = '';
      unit.text = '';
      prodi.text = '';
    });
    final files = (await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const RekamWajah(),
      ),
    ));
    if (files != null) {
      imglib.Image? imageLoaded = await _loadImage(files);
      setState(() {
        // isLoading = true;
        imageFile = files;
        if (imageLoaded != null) {
          imageSize = Size(
            imageLoaded.width.toDouble(),
            imageLoaded.height.toDouble(),
          );
        }
      });

      dynamic finalResult = Multimap<String, Face>();
      final image = InputImage.fromFile(files);
      final faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      List<Map<String, Mahasiswa>> listMHS = dataMhs == null
          ? []
          : dataMhs
              .map((dt) => {
                    dt.id: Mahasiswa.fromFirestoreMap(
                        dt.id, dt.data()["info"] as Map<String, Object?>)
                  })
              .toList();
      List<Map<String, Absensi>> listAbsensi = dataAbsensi == null
          ? []
          : dataAbsensi.map((dt) {
              Absensi ab = Absensi.fromFirestore(dt.data(), dt.id);
              return {ab.userID!: ab};
            }).toList();

      String res = "";
      Mahasiswa mhs;
      Face face;
      List<Face> faces = await faceDetector.processImage(image);
      await Future.delayed(const Duration(milliseconds: 500));
      Interpreter? interp = await loadModel();
      setState(() {
        interpreter = interp;
      });

      if (status != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("status", status);
      }

      if (mounted) {
        for (face in faces) {
          double x, y, w, h;
          x = (face.boundingBox.left - 10);
          y = (face.boundingBox.top - 10);
          w = (face.boundingBox.width + 10);
          h = (face.boundingBox.height + 10);
          imglib.Image croppedImage = imglib.copyCrop(
              imageLoaded!, x.round(), y.round(), w.round(), h.round());
          croppedImage = imglib.copyResizeCropSquare(croppedImage, 112);
          res = recog(croppedImage, listMHS);
          finalResult.add(res, face);
        }

        if (res != "Tidak dikenali") {
          Map<String, Mahasiswa> dtMHS = {};
          Map<String, Absensi> dtAbs = {};

          for (Map<String, Mahasiswa> dt1 in listMHS) {
            for (String label in dt1.keys) {
              if (label == res) {
                dtMHS = dt1;
              }
            }
          }

          for (Map<String, Absensi> dt2 in listAbsensi) {
            for (String label in dt2.keys) {
              if (label == res) {
                dtAbs = dt2;
              }
            }
          }
          mhs = dtMHS[res]!;
          Absensi? absen = dtAbs[res];

          if (absen != null && absen.keluar! > 0) {
            setState(() {
              imageFile = null;
            });
            snackbar.currentState!.showSnackBar(const SnackBar(
                content: Text("Tidak Bisa Absen Kembali setelah keluar")));
          }

          setState(() {
            isDetected = true;
            isLoading = false;
            kdAbsen.text = mhs.nim!;
            nim.text = mhs.nim!;
            nama.text = mhs.nama!;
            semester.text = mhs.semester!;
            unit.text = mhs.unit!;
            prodi.text = mhs.prodi!;
            mahasiswa = mhs;
            scanResult = res;
            waktu = DateTime.now().millisecondsSinceEpoch;
          });
          if (absen != null) {
            DateTime startDay = DateTime(DateTime.now().year,
                DateTime.now().month, DateTime.now().day, 0, 0, 0);
            DateTime endDay = DateTime(DateTime.now().year,
                DateTime.now().month, DateTime.now().day, 23, 59, 59);
            if (absen.masuk! > startDay.millisecondsSinceEpoch &&
                absen.masuk! < endDay.millisecondsSinceEpoch &&
                absen.keluar! == 0) {
              setState(() {
                statusAbsensi = "keluar";
                absensi = absen.keluar == 0 ? absen : null;
                kdMK.text = absen.kodeMK!;
              });
            } else {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("status", "Masuk");
            }
          }
        } else {
          // ignore: use_build_context_synchronously
          snackbar.currentState!.showSnackBar(
              const SnackBar(content: Text("Wajah Tidak Terdeteksi")));
        }
      }
    }
  }

  Future<void> handleSimpanData() async {
    final prefs = await SharedPreferences.getInstance();
    String status = (prefs.getString("status"))!;

    if (isDetected == true) {
      if (form.currentState!.validate()) {
        if (status == "Masuk" && absensi == null) {
          simpanDataMasuk(status);
        } else {
          simpanDataKeluar(status);
        }
      }
    } else {
      // ignore: use_build_context_synchronously
      snackbar.currentState!.showSnackBar(
          const SnackBar(content: Text("Wajah Tidak Terdeteksi")));
    }
  }

  Future<void> simpanDataMasuk(String status) async {
    Map<String, dynamic> map = {
      "userID": mahasiswa.uid,
      "masuk": waktu,
      "keluar": 0,
      "status": "masuk",
      "kodeMK": kdMK.text,
    };

    refAbsensi.add(map).then((_) {
      setState(() {
        isDetected = false;
        kdAbsen.text = "";
        nim.text = "";
        nama.text = "";
        semester.text = "";
        unit.text = "";
        prodi.text = "";
        scanResult = null;
        waktu = 0;
        imageFile = null;
        e1 = null;
        kdMK.text = "";
        absensi = null;
      });
      // ignore: use_build_context_synchronously
      snackbar.currentState!.showSnackBar(
          const SnackBar(content: Text("Data Berhasil Disimpan")));
    }).catchError((error) {
      // ignore: use_build_context_synchronously
      snackbar.currentState!
          .showSnackBar(SnackBar(content: Text("Data Gagal Disimpan: $error")));
    });
  }

  Future<void> simpanDataKeluar(String status) async {
    Map<String, dynamic> map = {
      "keluar": waktu,
      "status": "keluar",
    };

    refAbsensi.doc(absensi!.docID).update(map).then((_) {
      setState(() {
        isDetected = false;
        kdAbsen.text = "";
        nim.text = "";
        nama.text = "";
        semester.text = "";
        unit.text = "";
        prodi.text = "";
        scanResult = null;
        waktu = 0;
        imageFile = null;
        e1 = null;
        kdMK.text = "";
        absensi = null;
      });
      // ignore: use_build_context_synchronously
      snackbar.currentState!.showSnackBar(const SnackBar(
          content: Text("Selamat, Anda Telah Menyelesaikan MK")));
    }).catchError((error) {
      // ignore: use_build_context_synchronously
      snackbar.currentState!
          .showSnackBar(SnackBar(content: Text("Data Gagal Disimpan: $error")));
    });
  }

  Size imageSized(BuildContext context) {
    return Size(MediaQuery.of(context).size.width - 240,
        MediaQuery.of(context).size.width - 200);
  }

  Future _logout() async {
    Navigator.of(context).pop();
    await AuthService.singOut();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackbar,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Absensi"),
          actions: [
            StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
              stream: refMataKuliah.snapshots(),
              builder: ((context, snapshot) {
                if (snapshot.data == null || !snapshot.hasData) {
                  return const Center(
                    child: Text("Data Tidak Ditemukan."),
                  );
                }

                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    focusColor: Colors.white,
                    dropdownColor: Colors.deepOrange,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    iconEnabledColor: Colors.white,
                    hint: const Text("Mata Kuliah"),
                    value: mk,
                    items: [
                      const DropdownMenuItem<String>(
                        value: "pilih",
                        child: Text(
                          "Pilh Mata Kuliah",
                        ),
                      ),
                      ...snapshot.data!.docs.map((doc) {
                        Map<String, dynamic> dt = doc.data();
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            '${dt["matkul"]}',
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        mk = value!;
                      });
                    },
                  ),
                );
              }),
            ),
          ],
        ),
        drawer: drawerComponent(context),
        body: Stack(
          children: [
            if (isLoading == true)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  color: Colors.black54.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            Card(
              margin: const EdgeInsets.only(
                left: 15,
                right: 15,
                bottom: 15,
                top: 10,
              ),
              elevation: 5,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: imageFile == null
                    ? SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: userStream(),
                      )
                    : Column(
                        children: [
                          headerComponent(),
                          imageComponent(context),
                          buttonComponent(context),
                          dataMahasiswaComponent(context),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget absenMasukKeluar(
    BuildContext context, {
    List<QueryDocumentSnapshot<Map<String, Object?>>>? dataMhs,
    List<QueryDocumentSnapshot<Map<String, Object?>>>? dataAbsensi,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
              onPressed: () {
                handleAbsenMasuk(
                  context,
                  "Masuk",
                  dataMhs: dataMhs,
                  dataAbsensi: dataAbsensi,
                );
              },
              child: const Text("Absen Masuk")),
          ElevatedButton(
              onPressed: () {
                handleAbsenMasuk(
                  context,
                  "Keluar",
                  dataMhs: dataMhs,
                  dataAbsensi: dataAbsensi,
                );
              },
              child: const Text(
                "Absen Keluar",
              )),
        ],
      ),
    );
  }

  Expanded dataMahasiswaComponent(BuildContext context) {
    return Expanded(
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: form,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _textField(
                  label: "Kode Absen",
                  enabled: false,
                  controller: kdAbsen,
                ),
                _textField(label: "Nim", enabled: false, controller: nim),
                _textField(
                  label: "Nama",
                  enabled: false,
                  value: respon,
                  controller: nama,
                ),
                _textField(
                  label: "Semester",
                  enabled: false,
                  controller: semester,
                  minLengthValues: 1,
                ),
                _textField(label: "Unit", enabled: false, controller: unit),
                _textField(label: "Prodi", enabled: false, controller: prodi),
                _textField(
                  label: "Kode MK",
                  controller: kdMK,
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Row buttonComponent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ElevatedButton(
          child: const Text("Kembali"),
          onPressed: () {
            if (interpreter != null || !interpreter!.isDeleted) {
              interpreter!.close();
            }
            setState(() {
              imageFile = null;
              e1 = null;
              kdAbsen.text = '';
              kdMK.text = '';
              nim.text = '';
              nama.text = '';
              semester.text = '';
              unit.text = '';
              prodi.text = '';
              absensi = null;
            });
          },
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => handleAbsenMasuk(context, null),
          child: const Text("Rekam Ulang"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: Text(statusAbsensi.toUpperCase()),
          onPressed: handleSimpanData,
        ),
      ],
    );
  }

  Container imageComponent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7, left: 20, right: 20),
      width: imageSized(context).width,
      height: imageSized(context).height,
      color: Colors.grey[200],
      child: imageFile == null
          ? Image.asset("person.png", fit: BoxFit.cover)
          : Image.file(
              height: imageSize.height - (imageSize.height * 0.3),
              imageFile!,
              fit: BoxFit.fitWidth,
            ),
    );
  }

  Center headerComponent() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 15, top: 15),
        child: const Text(
          "DATA MAHASISWA",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Drawer drawerComponent(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                "Selamat Datang, ${user.name}",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            title: const Text("Data Mahasiswa"),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) {
                if (interpreter != null && !interpreter!.isDeleted) {
                  interpreter!.close();
                }
                return const InputPeserta();
              }),
            ),
          ),
          ListTile(
            title: const Text("Data Absensi"),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) {
                if (interpreter != null && !interpreter!.isDeleted) {
                  interpreter!.close();
                }
                return const Presensi();
              }),
            ),
          ),
          ListTile(
            title: const Text("Mata Kuliah"),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) {
                if (interpreter != null && !interpreter!.isDeleted) {
                  interpreter!.close();
                }
                return const MataKuliah();
              }),
            ),
          ),
          ListTile(
            title: const Text("Laporan"),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) {
                if (interpreter != null && !interpreter!.isDeleted) {
                  interpreter!.close();
                }
                return const Laporan();
              }),
            ),
          ),
          ListTile(
            title: const Text("Akun Admin"),
            onTap: () async {
              String? logout = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (context) {
                  if (interpreter != null && !interpreter!.isDeleted) {
                    interpreter!.close();
                  }
                  return AkunAdmin(
                    user: widget.user,
                  );
                }),
              );
              if (logout != null) _logout();
            },
          ),
          ListTile(
            title: const Text("Keluar"),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Yakin ingin Keluar?"),
                    actions: [
                      TextButton(
                          child: const Text("Tidak"),
                          onPressed: () {
                            if (interpreter != null &&
                                !interpreter!.isDeleted) {
                              interpreter!.close();
                            }
                            Navigator.of(context).pop();
                          }),
                      TextButton(onPressed: _logout, child: const Text("Ya")),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    bool enabled = true,
    String? value,
    TextEditingController? controller,
    // Validator
    bool notNull = true,
    bool regexNoSpace = false,
    int minLengthValues = 5,
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
      margin: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        initialValue: value,
        validator: validator,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(6),
          hintText: label,
          icon: SizedBox(
            width: MediaQuery.of(context).size.width / 6,
            child: Text(label),
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget dateInfo() {
    Map<String, int> date = startEndDay(DateTime.now());
    String day = dateTime(DateTime.now(), disabledHour: true);
    String start = dateTime(
      DateTime.fromMillisecondsSinceEpoch(date['start']!),
      disabledDay: true,
    );
    String end = dateTime(
      DateTime.fromMillisecondsSinceEpoch(date['end']!),
      disabledDay: true,
    );
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Center(
        child: Text(
          "$day $start sampai $end",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget userStream() {
    Map<String, int> date = startEndDay(DateTime.now());
    return StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
      stream: FirestoreDatabase.collection("users")
          .where("role", isEqualTo: "mahasiswa")
          .orderBy("name")
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot1) {
        if (snapshot1.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot1.data == null || !snapshot1.hasData) {
          return const Center(
            child: Text("Data Tidak Ditemukan."),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
            stream: refAbsensi
                .where("masuk", isGreaterThan: date["start"])
                .where("masuk", isLessThan: date["end"])
                .where("kodeMK", isEqualTo: mk)
                .orderBy("masuk", descending: true)
                .snapshots(includeMetadataChanges: true),
            builder: (context, snapshot2) {
              return Column(
                children: [
                  dateInfo(),
                  absenMasukKeluar(
                    context,
                    dataMhs: snapshot1.data!.docs,
                    dataAbsensi:
                        snapshot2.data == null ? [] : snapshot2.data!.docs,
                  ),
                  Expanded(
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      padding: const EdgeInsets.only(
                          bottom: 10, left: 10, right: 10, top: 5),
                      child: ListView.builder(
                        itemCount: snapshot1.data!.docs.length,
                        itemBuilder: (context, index1) {
                          QueryDocumentSnapshot<Map<String, Object?>> dtUser =
                              snapshot1.data!.docs[index1];
                          Mahasiswa mhs = Mahasiswa.fromFirestoreMap(dtUser.id,
                              dtUser.data()["info"] as Map<String, Object?>);
                          List<Map<String, Absensi>> listAbsensi =
                              snapshot2.data == null
                                  ? []
                                  : snapshot2.data!.docs.map((dt) {
                                      Absensi ab = Absensi.fromFirestore(
                                          dt.data(), dt.id);
                                      return {ab.userID!: ab};
                                    }).toList();
                          if (listAbsensi.isNotEmpty) {
                            Map<String, Absensi?> dataAbsensi = {};
                            for (Map<String, Absensi> dd in listAbsensi) {
                              if (dd[mhs.uid] != null) {
                                dataAbsensi.putIfAbsent(
                                    mhs.uid!, () => dd[mhs.uid]!);
                              }
                            }
                            if (dataAbsensi[mhs.uid] != null) {
                              return dataList(
                                context,
                                mhs,
                                dataAbsensi[mhs.uid]!,
                              );
                            } else {
                              return Card(
                                child: ListTile(
                                  title: Text(mhs.nama!),
                                  subtitle: const Text("Belum Absen / Alpha"),
                                ),
                              );
                            }
                          } else {
                            return Card(
                              child: ListTile(
                                title: Text(mhs.nama!),
                                subtitle:
                                    const Text("Silahkan Pilih Mata Kuliah"),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            });
      },
    );
  }

  Card dataList(BuildContext context, Mahasiswa mhs, Absensi absensi) {
    DateTime masuk = DateTime.fromMillisecondsSinceEpoch(absensi.masuk!);
    DateTime keluar = DateTime.fromMillisecondsSinceEpoch(absensi.keluar!);

    return Card(
      child: ListTile(
        title: Text(
          "${mhs.nama} (${mhs.nim!})",
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: mhs.uid == absensi.userID
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Kode Mata Kuliah (${absensi.kodeMK!.toUpperCase()})",
                    style: const TextStyle(color: Colors.lightBlue),
                  ),
                  Text(
                    "Masuk ${dateTime(masuk)}",
                    style: const TextStyle(color: Colors.lightGreen),
                  ),
                  Text(
                    absensi.keluar! == 0
                        ? "Sedang Melangsungkan Pembelajaran"
                        : "Keluar ${dateTime(keluar)}",
                    style: TextStyle(color: Colors.redAccent[700]),
                  ),
                ],
              )
            : const Text("Mahasiswa Belum Masuk Kelas"),
      ),
    );
  }

  Future<imglib.Image?> _loadImage(File? file) async {
    if (file != null) {
      final data = await file.readAsBytes();
      return imglib.decodeImage(data);
    }

    return null;
  }
}
