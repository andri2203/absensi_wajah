import 'dart:convert';
import 'dart:io';

import 'package:absensi_wajah/resource/mahasiswa.dart';
import 'package:absensi_wajah/screens/rekam_wajah.dart';
import 'package:absensi_wajah/utils/model.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiver/collection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path/path.dart' as path;
import '../utils/utils.dart';

class InputPeserta extends StatefulWidget {
  const InputPeserta({Key? key}) : super(key: key);

  @override
  State<InputPeserta> createState() => _InputPesertaState();
}

class _InputPesertaState extends State<InputPeserta>
    with SingleTickerProviderStateMixin {
  final TableMahasiswa tbMahasiswa = TableMahasiswa();
  List<Mahasiswa?> mahasiswa = [];
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController nim = TextEditingController();
  final TextEditingController nama = TextEditingController();
  final TextEditingController semester = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController prodi = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    initJsonFile();
    controller = AnimationController(vsync: this);
  }

  initJsonFile() async {
    tempDir = await getApplicationDocumentsDirectory();
    String embPath = '${tempDir!.path}/emb.json';
    jsonFile = File(embPath);
    if (jsonFile.existsSync()) {
      data = json.decode(jsonFile.readAsStringSync());
    }
  }

  Future<List<Mahasiswa?>> getData() async {
    List<Mahasiswa?> maps = [];
    maps = (await tbMahasiswa.get())!;
    return maps;
  }

  handleRekamWajah() async {
    File? file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) {
        return const RekamWajah();
      }),
    );

    if (file != null) {
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
            if (response == "TIDAK DIKENALI") {
              setState(() {
                imageFile = file;
                imageSize =
                    Size(image!.width.toDouble(), image.height.toDouble());
                scanResult = finalResult;
                isLoading = false;
              });

              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text("Wajah Tidak Dikenal. Silahkan Tambah Mahasiswa")));
            } else {
              Mahasiswa mhs = (await tbMahasiswa.getByNim(response))!;
              setState(() {
                imageFile = File(mhs.foto!);
                peserta = mhs;
                nim.text = mhs.nim!;
                nama.text = mhs.nama!;
                semester.text = mhs.semester!;
                unit.text = mhs.unit!;
                prodi.text = mhs.prodi!;
                isLoading = false;
              });
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    "Wajah Di Dikenal. Silahkan Ubah Data. Jika Diperlukan."),
              ));
            }
          } else {
            interpreter.close();
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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

  handleSimpanData() async {
    String newPath = await getPath();
    if (form.currentState!.validate() && e1 != null) {
      String basNameWithExt = path.basename(imageFile!.path);
      File newFile = await moveFile(imageFile!, "$newPath/$basNameWithExt");
      Map<String, Object?> maps = {
        tbMahasiswa.nim: nim.text,
        tbMahasiswa.nama: nama.text,
        tbMahasiswa.semester: semester.text,
        tbMahasiswa.unit: unit.text,
        tbMahasiswa.prodi: prodi.text,
        tbMahasiswa.foto: newFile.path,
      };
      Mahasiswa? mhs = await tbMahasiswa.add(Mahasiswa.fromMap(maps));

      if (mounted) {
        if (mhs != null) {
          data[mhs.nim] = e1;
          jsonFile.writeAsStringSync(json.encode(data));
          getData();
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
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Data Berhasil Di Tambah")));
        }
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data Gagal Di Tambah")));
      }
    }
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon Periksa Field dan Gambar Wajah")));
  }

  handleUpdateData() async {
    if (form.currentState!.validate()) {
      Map<String, Object?> map = {
        tbMahasiswa.id: peserta!.id,
        tbMahasiswa.nim: nim.text,
        tbMahasiswa.nama: nama.text,
        tbMahasiswa.semester: semester.text,
        tbMahasiswa.unit: unit.text,
        tbMahasiswa.prodi: prodi.text,
        tbMahasiswa.foto: peserta!.foto,
      };

      Mahasiswa data = Mahasiswa.fromMap(map);
      int update = await tbMahasiswa.update(data);

      if (update > 0) {
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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data Berhasil Di Ubah")));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Data gagal Di Ubah. Mohon Coba Lagi.")));
      }
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
    return compare(e1!).toUpperCase();
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
    return Scaffold(
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
                    isCreateData = !isCreateData;
                    imageFile = null;
                    e1 = null;
                    nim.text = '';
                    nama.text = '';
                    semester.text = '';
                    unit.text = '';
                    prodi.text = '';
                  });
                },
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: Icon(peserta == null ? Icons.save : Icons.edit),
                label: Text(peserta == null ? "Simpan" : "Ubah"),
                onPressed:
                    peserta == null ? handleSimpanData : handleUpdateData,
              ),
            ]),
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
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Cari Mahasiswa",
              suffixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(horizontal: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(25)),
              ),
            ),
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
            child: dataBuilder(),
          ),
        ),
      ],
    );
  }

  Widget dataBuilder() {
    return FutureBuilder<List<Mahasiswa?>>(
      future: getData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return dataList(context, snapshot.data![index]);
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
          child: Image.file(File(mhs.foto!), fit: BoxFit.fitWidth, width: 50),
        ),
        trailing: IconButton(
            onPressed: () {
              setState(() {
                isCreateData = true;
                imageFile = File(mhs.foto!);
                peserta = mhs;
                nim.text = mhs.nim!;
                nama.text = mhs.nama!;
                semester.text = mhs.semester!;
                unit.text = mhs.unit!;
                prodi.text = mhs.prodi!;
              });
            },
            icon: const Icon(
              Icons.edit,
              color: Colors.green,
            )),
      ),
    );
  }

  TableRow tableHead(List<String> columns) {
    return TableRow(
      decoration: const BoxDecoration(),
      children: columns
          .map((column) => TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Text(column,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ))
          .toList(),
    );
  }
}
