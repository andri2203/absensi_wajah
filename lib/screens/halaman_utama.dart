import 'dart:convert';
import 'dart:io';

import 'package:absensi_wajah/resource/absensi.dart';
import 'package:absensi_wajah/resource/admin.dart';
import 'package:absensi_wajah/resource/mahasiswa.dart';
import 'package:absensi_wajah/screens/input_peserta.dart';
import 'package:absensi_wajah/screens/laporan.dart';
import 'package:absensi_wajah/screens/login.dart';
import 'package:absensi_wajah/screens/presensi.dart';
import 'package:absensi_wajah/screens/rekam_wajah.dart';
import 'package:absensi_wajah/utils/model.dart';
import 'package:absensi_wajah/utils/utils.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:path_provider/path_provider.dart';
import 'package:quiver/collection.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({Key? key, required this.title, required this.admin})
      : super(key: key);

  final String title;
  final Admin admin;

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  Admin? admin;
  File? imageFile;
  Size imageSize = const Size(0, 0);
  dynamic scanResult;
  TableMahasiswa tableMahasiswa = TableMahasiswa();
  TableAbsensi tbAbsensi = TableAbsensi();
  bool isLoading = false;
  late Mahasiswa mahasiswa;
  late int waktu;

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

  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController nim = TextEditingController();
  final TextEditingController nama = TextEditingController();
  final TextEditingController semester = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController prodi = TextEditingController();
  final TextEditingController kdAbsen = TextEditingController();
  final TextEditingController kdMK = TextEditingController();

  @override
  void initState() {
    super.initState();
    start();
  }

  void start() {
    admin = widget.admin;
    initJsonFile();
  }

  initJsonFile() async {
    tempDir = await getApplicationDocumentsDirectory();
    String embPath = '${tempDir!.path}/emb.json';
    jsonFile = File(embPath);
    if (jsonFile.existsSync()) {
      setState(() {
        data = json.decode(jsonFile.readAsStringSync());
      });
    }
  }

  String recog(imglib.Image img) {
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
      return compare(e1!).toUpperCase();
    }

    return "Terjadi Kesalahan.";
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

  Future handleAbsenMasuk(BuildContext context, String? status) async {
    initJsonFile();
    setState(() {
      imageFile = null;
      e1 = null;
      interpreter = null;
      kdAbsen.text = '';
      kdMK.text = '';
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

      String? res;
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
          res = recog(croppedImage);
          finalResult.add(res, face);
        }

        if (res != "TIDAK DIKENALI") {
          mhs = (await tableMahasiswa.getByNim(res!))!;
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
        }
      }
    }
  }

  Future<void> handleSimpanData() async {
    final prefs = await SharedPreferences.getInstance();
    String status = (prefs.getString("status"))!;

    if (isDetected == true) {
      if (form.currentState!.validate()) {
        if (status == "Masuk") {
          simpanDataMasuk(status);
        } else {
          simpanDataKeluar(status);
        }
      }
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wajah Tidak Terdeteksi")));
    }
  }

  Future<void> simpanDataMasuk(String status) async {
    Map<String, dynamic> map = {
      tbAbsensi.idMahasiswa: mahasiswa.id.toString(),
      tbAbsensi.masuk: waktu,
      tbAbsensi.keluar: 0,
      tbAbsensi.status: status,
      tbAbsensi.kodeMK: kdMK.text,
    };

    Absensi? absensi = await tbAbsensi.add(Absensi.fromMap(map));

    if (absensi != null) {
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
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data Berhasil Disimpan")));
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Data Gagal Disimpan")));
    }
  }

  Future<void> simpanDataKeluar(String status) async {}

  Size imageSized(BuildContext context) {
    return Size(MediaQuery.of(context).size.width - 240,
        MediaQuery.of(context).size.width - 200);
  }

  Future _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.remove("adminID");

    if (mounted && success) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => const Login(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
            margin: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
            elevation: 5,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              handleAbsenMasuk(context, "Masuk");
                            },
                            child: const Text("Absen Masuk")),
                        ElevatedButton(
                            onPressed: () async {
                              // handleAbsenMasuk(context, "Keluar");
                              var data = await tbAbsensi.get();
                              for (var i = 0; i < data.length; i++) {
                                print(data[i]?.status);
                              }
                            },
                            child: const Text(
                              "Absen Keluar",
                            )),
                      ],
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
                _textField(label: "Kode MK", controller: kdMK),
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
          label: const Text("Simpan"),
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
                "Selamat Datang, ${admin?.username}",
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

  Future<imglib.Image?> _loadImage(File? file) async {
    if (file != null) {
      final data = await file.readAsBytes();
      return imglib.decodeImage(data);
    }

    return null;
  }
}
