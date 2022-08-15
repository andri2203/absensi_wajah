import 'dart:convert';
import 'dart:io';

import 'package:absensi_wajah/screens/akun_admin.dart';
import 'package:absensi_wajah/utils/date_time.dart';
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
  TableMahasiswa tbMahasiswa = TableMahasiswa();
  List<Map<String, Object?>> dataMahasiswa = [];
  List<Absensi?> dtAbsensi = [];
  TableAbsensi tbAbsensi = TableAbsensi();
  bool isLoading = false;
  late Mahasiswa mahasiswa;
  Absensi? absensi;
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
  String? seacrh;

  @override
  void initState() {
    super.initState();
    start();
  }

  void start() {
    admin = widget.admin;
    initJsonFile();
    getDataMahasiswa();
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
    getDataMahasiswa();
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
      absensi = null;
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
          mhs = (await tbMahasiswa.getByNim(res!))!;
          List<Absensi?> list = (await tbAbsensi.getByIdMahasiswa(mhs.id!))
              .where((dt) => dt!.keluar == 0)
              .toList();
          Absensi? absen = list.isNotEmpty ? list.last : null;

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
            if (absen != null) {
              absensi = absen.keluar == 0 ? absen : null;
              kdMK.text = absen.id == null ? "" : absen.kodeMK!;
            }
          });
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Wajah Tidak Terdeteksi")));
        }
      }
    }
  }

  Future<void> getDataMahasiswa() async {
    List<Map<String, Object?>> dt = [];
    List<Mahasiswa?> maps = [];
    maps = (await tbMahasiswa.get())!;

    for (var i = 0; i < maps.length; i++) {
      dt.add(maps[i]!.toMap());
    }

    setState(() {
      dataMahasiswa = dt;
    });
  }

  Future<List<Absensi?>> getDataAbsensi() async {
    Map<String, int> date = startEndDay(DateTime.now());
    List<Absensi?> maps = [];
    maps = (await tbAbsensi.getOneDayOnly(date['start']!, date['end']!));
    return maps;
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
        kdMK.text = "";
        absensi = null;
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

  Future<void> simpanDataKeluar(String status) async {
    Map<String, dynamic> map = {
      tbAbsensi.id: absensi!.id,
      tbAbsensi.idMahasiswa: absensi!.idMahasiswa,
      tbAbsensi.masuk: absensi!.masuk,
      tbAbsensi.keluar: waktu,
      tbAbsensi.status: "Keluar",
      tbAbsensi.kodeMK: absensi!.kodeMK,
    };

    int update = await tbAbsensi.update(Absensi.fromMap(map));
    if (update > 0) {
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
        absensi = null;
        kdMK.text = "";
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Data Berhasil Di Ubah")));
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Gagal Merubah data. Silahkan Perikasa")));
    }
  }

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
                  ? Column(
                      children: [
                        dateInfo(),
                        absenMasukKeluar(context),
                        Expanded(
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            padding: const EdgeInsets.only(
                                bottom: 10, left: 10, right: 10, top: 5),
                            child: dataBuilder(),
                          ),
                        ),
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

  Widget absenMasukKeluar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
              onPressed: () {
                handleAbsenMasuk(context, "Masuk");
              },
              child: const Text("Absen Masuk")),
          ElevatedButton(
              onPressed: () {
                handleAbsenMasuk(context, "Keluar");
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
                return const AkunAdmin();
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

  Widget seacrhBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        onChanged: (value) {
          setState(() {
            seacrh = value;
          });
        },
        decoration: const InputDecoration(
          hintText: "Cari Mahasiswa",
          suffixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(25)),
          ),
        ),
      ),
    );
  }

  Widget dataBuilder() {
    return FutureBuilder<List<Absensi?>>(
      future: getDataAbsensi(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null) {
            List<Absensi?> dataAbsensi = snapshot.data!;

            return ListView.builder(
              itemCount: dataAbsensi.length,
              itemBuilder: (context, index) {
                return dataList(context, dataAbsensi[index]);
              },
            );
          } else {
            return const Center(
              child: Text("Data Tidak Ditemukan."),
            );
          }
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Card dataList(BuildContext context, Absensi? absensi) {
    int index = dataMahasiswa.indexWhere(
      (element) => element[tbMahasiswa.id].toString() == absensi!.idMahasiswa,
    );

    Mahasiswa? mhs = Mahasiswa.fromMap(dataMahasiswa[index]);
    DateTime masuk = DateTime.fromMillisecondsSinceEpoch(absensi!.masuk!);
    DateTime keluar = DateTime.fromMillisecondsSinceEpoch(absensi.keluar!);

    return Card(
      child: ListTile(
        title: Text(
          "${mhs.nama} (${mhs.nim!})",
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Column(
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
