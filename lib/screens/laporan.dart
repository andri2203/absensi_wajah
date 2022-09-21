import 'dart:io';

import 'package:absensi_wajah/resource/absensi.dart';
import 'package:absensi_wajah/resource/mahasiswa.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../firebase/firestore.dart';

class Laporan extends StatefulWidget {
  const Laporan({Key? key}) : super(key: key);

  @override
  State<Laporan> createState() => _LaporanState();
}

class _LaporanState extends State<Laporan> {
  List<Map<String, Object?>> data = [];
  DateTime now = DateTime.now();
  List<String> listBulan = [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember",
  ];
  int indexBulan = DateTime.now().month - 1;
  int tahun = DateTime.now().year;
  int indexLaporan = 1;

  // Field Maps
  String fieldMahasiswa = "mahasiswa";
  String fieldJumlahHadir = "hadir";
  String fieldJumlahAlpa = "alpa";
  String fieldAbsensi = "absen";

  // Firestore
  CollectionReference<Map<String, dynamic>> refUsers =
      FirestoreDatabase.collection("users");
  CollectionReference<Map<String, dynamic>> refMataKuliah =
      FirestoreDatabase.collection("mataKuliah");
  CollectionReference<Map<String, dynamic>> refAbsensi =
      FirestoreDatabase.collection("absensi");
  String mk = "pilih";

  final GlobalKey<ScaffoldMessengerState> scaffold =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
  }

  pw.Padding tableCell(String data,
      {pw.TextAlign textAlign = pw.TextAlign.left,
      pw.TextStyle style = const pw.TextStyle()}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 7),
      child: pw.Text(data, textAlign: textAlign, style: style),
    );
  }

  Future<String> getDirectory() async {
    Directory? dir = await getExternalStorageDirectory();
    Directory path = Directory("${dir!.path}/Berkas");
    path.create();
    return path.path;
  }

  Stream<List<FileSystemEntity>> getFileOnDirectory() async* {
    String path = await getDirectory();
    Directory files = Directory(path);
    yield* files.list().toList().asStream();
  }

  int jumlahPertemuan() {
    int bulan = indexBulan + 1;
    DateTime endDay = bulan < 12
        ? DateTime(tahun, bulan + 1, 0, 23, 59, 59)
        : DateTime(tahun + 1, 1, 0, 23, 59, 59);
    int pertemuan = 0;

    for (var day = 1; day <= endDay.day; day++) {
      DateTime hari = DateTime(tahun, bulan, day);
      if (hari.weekday <= 5) {
        pertemuan += 1;
      }
    }

    return pertemuan;
  }

  Future<void> getData(BuildContext context) async {
    if (mk == "pilih") {
      scaffold.currentState!.showSnackBar(
        const SnackBar(content: Text("Silahkan Pilih Mata Kuliah")),
      );
      return;
    }
    int bulan = indexBulan + 1;
    DateTime startDay = DateTime(tahun, bulan, 1);
    DateTime endDay = bulan < 12
        ? DateTime(tahun, bulan + 1, 0, 23, 59, 59)
        : DateTime(tahun + 1, 1, 0, 23, 59, 59);
    List<Absensi> absensi = await refAbsensi
        .where("masuk", isGreaterThan: startDay.millisecondsSinceEpoch)
        .where("masuk", isLessThan: endDay.millisecondsSinceEpoch)
        .where("kodeMK", isEqualTo: mk)
        .orderBy("masuk", descending: true)
        .get()
        .then((value) => value.docs
            .map((e) => Absensi.fromFirestore(e.data(), e.id))
            .toList());
    List<Mahasiswa> mahasiswa = await refUsers
        .where("role", isEqualTo: "mahasiswa")
        .orderBy("name")
        .get()
        .then((value) => value.docs
            .map((e) => Mahasiswa.fromFirestoreMap(e.id, e.data()["info"]))
            .toList());
    Map<String, dynamic>? mtkl =
        await refMataKuliah.doc(mk).get().then((value) => value.data());
    if (mounted) {
      if (indexLaporan == 1) {
        dataRekapKehadiran(mahasiswa, absensi, context, mtkl);
      } else {
        dataRingkasanAbsensi(mahasiswa, absensi, context, mtkl);
      }
    }
  }

  dataRekapKehadiran(List<Mahasiswa?> mahasiswa, List<Absensi?> absensi,
      BuildContext context, Map<String, dynamic>? mtkl) async {
    int bulan = indexBulan + 1;
    DateTime endDay = bulan < 12
        ? DateTime(tahun, bulan + 1, 0, 23, 59, 59)
        : DateTime(tahun + 1, 1, 0, 23, 59, 59);
    List<Map<String, Object?>> maps = [];
    int pertemuan = jumlahPertemuan();

    for (var i = 0; i < mahasiswa.length; i++) {
      int hadir = 0;
      Mahasiswa mhs = mahasiswa[i]!;

      for (var day = 1; day <= endDay.day; day++) {
        int dayEpochStart =
            DateTime(tahun, bulan, day, 0, 0, 0).millisecondsSinceEpoch;
        int dayEpochEnd =
            DateTime(tahun, bulan, day, 23, 59, 59).millisecondsSinceEpoch;

        List<Absensi?> dt =
            absensi.where((val) => val!.userID == mhs.uid).toList();

        for (var i = 0; i < dt.length; i++) {
          Absensi abs = dt[i]!;
          if (abs.masuk! > dayEpochStart && abs.masuk! < dayEpochEnd) {
            hadir += 1;
          }
        }
      }

      Map<String, Object?> map = {
        fieldMahasiswa: mhs,
        fieldJumlahHadir: hadir,
        fieldJumlahAlpa: pertemuan - hadir,
      };

      maps.add(map);
    }

    final pw.Document pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      build: (ctx) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Center(
              child: pdfHeader(ctx, "DAFTAR ABSENSI MAHASISWA"),
            ),
            pw.Center(
              child: pw.Container(
                  margin: const pw.EdgeInsets.only(top: 20),
                  child: pw.Column(children: [
                    pw.SizedBox(
                      height: 25,
                      child: pw.Text(
                          "Laporan Rekap Kehadiran ${mtkl!['matkul']} Bulan ${listBulan[indexBulan]} $tahun"),
                    ),
                    pw.Table(
                        border: pw.TableBorder.all(width: 1),
                        columnWidths: {
                          0: const pw.FixedColumnWidth(100),
                          4: const pw.FixedColumnWidth(75),
                        },
                        children: <pw.TableRow>[
                          pw.TableRow(children: [
                            tableCell("Nama", textAlign: pw.TextAlign.center),
                            tableCell("Nim", textAlign: pw.TextAlign.center),
                            tableCell("Semester",
                                textAlign: pw.TextAlign.center),
                            tableCell("Unit", textAlign: pw.TextAlign.center),
                            tableCell("Prodi", textAlign: pw.TextAlign.center),
                            tableCell("Hadir", textAlign: pw.TextAlign.center),
                            tableCell("Alpa", textAlign: pw.TextAlign.center),
                          ]),
                          ...maps.map<pw.TableRow>((dt) {
                            Mahasiswa mhs = dt[fieldMahasiswa] as Mahasiswa;
                            return pw.TableRow(
                                verticalAlignment:
                                    pw.TableCellVerticalAlignment.middle,
                                children: [
                                  tableCell(mhs.nama!),
                                  tableCell(mhs.nim!),
                                  tableCell(mhs.semester!),
                                  tableCell(mhs.unit!),
                                  tableCell(mhs.prodi!),
                                  tableCell("${dt[fieldJumlahHadir]} Hari"),
                                  tableCell("${dt[fieldJumlahAlpa]} Hari"),
                                ]);
                          }).toList(),
                        ]),
                  ])),
            ),
            pdfFooter(ctx),
          ],
        );
      },
    ));

    final String output = await getDirectory();
    final File fileSave = File(
        "$output/lap-rekap-kehadiran_${listBulan[indexBulan]}-${tahun}_${now.millisecondsSinceEpoch}.pdf");
    await fileSave.writeAsBytes(await pdf.save());

    if (mounted) {
      scaffold.currentState!.showSnackBar(const SnackBar(
        content: Text("Berhasil Simpan Berkas"),
      ));
    }
  }

  pw.Container pdfHeader(pw.Context context, String header) {
    return pw.Container(
      child: pw.Column(children: [
        pw.Text("UNIVERSITAS UBUDIYAH INDONESIA",
            style: const pw.TextStyle(fontSize: 18)),
        pw.Text(header, style: const pw.TextStyle(fontSize: 18)),
      ]),
    );
  }

  pw.Container pdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Column(children: [
          pw.Text("Banda Aceh,   ${listBulan[indexBulan]} $tahun"),
          pw.Text("Ketua Prodi"),
          pw.SizedBox(height: 30),
          pw.Text("(......................)"),
        ]),
      ]),
    );
  }

  dataRingkasanAbsensi(List<Mahasiswa?> mahasiswa, List<Absensi?> absensi,
      BuildContext context, Map<String, dynamic>? mtkl) async {
    int bulan = indexBulan + 1;
    DateTime endDay = bulan < 12
        ? DateTime(tahun, bulan + 1, 0, 23, 59, 59)
        : DateTime(tahun + 1, 1, 0, 23, 59, 59);
    List<Map<String, dynamic>> maps = [];

    for (var i = 0; i < mahasiswa.length; i++) {
      Mahasiswa mhs = mahasiswa[i]!;
      List<Map<String, Object?>> dataAbsensi = [];

      for (var day = 1; day <= endDay.day; day++) {
        List<Map<String, Object?>> dt = absensi
            .where((val) => val!.userID == mhs.uid)
            .map((e) => e!.toFirestoreMap())
            .toList();
        List<Absensi> pisahPerTanggal = [];
        int startDayEpoch =
            DateTime(tahun, bulan, day, 0, 0, 0).millisecondsSinceEpoch;
        int endDayEpoch =
            DateTime(tahun, bulan, day, 23, 59, 59).millisecondsSinceEpoch;

        for (var i = 0; i < dt.length; i++) {
          Absensi abs = Absensi.fromFirestore(dt[i], dt[i]["docID"] as String);
          if (abs.masuk! > startDayEpoch && abs.masuk! < endDayEpoch) {
            pisahPerTanggal.add(abs);
          }
        }

        dataAbsensi.add({day.toString(): pisahPerTanggal});
      }

      Map<String, Object?> map = {
        fieldMahasiswa: mhs.toMap(),
        fieldAbsensi: dataAbsensi,
      };
      maps.add(map);
    }

    final pw.Document pdf = pw.Document();
    pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) {
            return [
              pw.Center(child: pdfHeader(ctx, "RINGKASAN ABSENSI MAHASISWA")),
              pw.Container(
                height: 25,
                margin: const pw.EdgeInsets.only(top: 20),
                child: pw.Center(
                  child: pw.Text(
                      "Laporan Ringkas Absensi ${mtkl!['matkul']} Bulan ${listBulan[indexBulan]} $tahun"),
                ),
              ),
              pw.SizedBox(height: 10),
              ...maps.map<pw.Widget>(
                (val) {
                  Mahasiswa mhs = Mahasiswa.fromFirestoreMap(
                      val[fieldMahasiswa]["uid"],
                      val[fieldMahasiswa] as Map<String, Object?>);
                  List<Map<String, Object?>> dt =
                      val[fieldAbsensi] as List<Map<String, Object?>>;

                  return pw.Column(children: [
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("${mhs.nama}(${mhs.nim})"),
                          pw.Text("Semester ${mhs.semester} / ${mhs.prodi}"),
                        ]),
                    pw.Divider(),
                    pw.Table(
                        tableWidth: pw.TableWidth.max,
                        border: pw.TableBorder.all(width: 1),
                        children: [
                          pw.TableRow(
                            children: dt
                                .map<pw.Widget>((d) => tableCell(
                                      d.keys.first,
                                      style: const pw.TextStyle(fontSize: 7),
                                    ))
                                .toList(),
                          ),
                          pw.TableRow(
                            children: dt.map<pw.Widget>((d) {
                              List<Absensi> a =
                                  d[d.keys.first] as List<Absensi>;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Column(
                                    children: a.map<pw.Widget>(
                                  (x) {
                                    DateTime inTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                      x.masuk!,
                                    );
                                    DateTime outTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                      x.keluar!,
                                    );
                                    String masuk =
                                        "${inTime.hour}:${inTime.minute}";
                                    String keluar =
                                        "${outTime.hour}:${outTime.minute}";
                                    return pw.Container(
                                      margin:
                                          const pw.EdgeInsets.only(bottom: 5),
                                      child: pw.Text("$masuk/$keluar",
                                          style:
                                              const pw.TextStyle(fontSize: 7)),
                                    );
                                  },
                                ).toList()),
                              );
                            }).toList(),
                          ),
                        ]),
                    pw.SizedBox(height: 7),
                  ]);
                },
              ).toList(),
            ];
          },
        ),
        index: 0);

    final String output = await getDirectory();
    final File fileSave = File(
        "$output/ringkasan-absensi_${listBulan[indexBulan]}-${tahun}_${now.millisecondsSinceEpoch}.pdf");
    await fileSave.writeAsBytes(await pdf.save());

    if (mounted) {
      scaffold.currentState!.showSnackBar(const SnackBar(
        content: Text("Berhasil Simpan Berkas"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffold,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Laporan Absensi"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "Laporan Absensi Periode ${listBulan[indexBulan]} $tahun",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              formDate(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                          hint: const Text("Mata Kuliah"),
                          value: mk,
                          items: [
                            const DropdownMenuItem<String>(
                              value: "pilih",
                              child: Text("Pilh Mata Kuliah"),
                            ),
                            ...snapshot.data!.docs.map((doc) {
                              Map<String, dynamic> dt = doc.data();
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text('${dt["matkul"]}'),
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
                  ElevatedButton.icon(
                    onPressed: () => getData(context),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Ekspor Ke PDF"),
                    style: ElevatedButton.styleFrom(),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 15),
                child: const Text(
                  "Riwayat Laporan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Divider(),
              dataBuilder(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget formDate() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropdownButton(
          value: indexLaporan,
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem(
              value: 1,
              child: Text("Rekap Kehadiran"),
            ),
            DropdownMenuItem(
              value: 2,
              child: Text("Ringkasan Absensi"),
            ),
          ],
          onChanged: (int? value) => setState(() {
            indexLaporan = value!;
          }),
        ),
        DropdownButton(
          value: indexBulan,
          items: listBulan
              .map<DropdownMenuItem<int>>((val) => DropdownMenuItem<int>(
                    value: listBulan.indexOf(val),
                    child: Text(val),
                  ))
              .toList(),
          onChanged: (int? value) => setState(() {
            indexBulan = value!;
          }),
        ),
        DropdownButton(
          value: tahun,
          items: List<DropdownMenuItem<int>>.generate(
            now.year - 2000 + 1,
            (index) => DropdownMenuItem<int>(
              value: now.year - index,
              child: Text((now.year - index).toString()),
            ),
            growable: true,
          ),
          onChanged: (int? value) => setState(() {
            tahun = value!;
          }),
        ),
      ],
    );
  }

  Widget dataBuilder(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<FileSystemEntity>>(
          stream: getFileOnDirectory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.none) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.data != null) {
              List<FileSystemEntity> list = snapshot.data!;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                        trailing: const Icon(Icons.share),
                        title: Text(
                          basename(list[index].path),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text("Lokasi : ${list[index].absolute.path}",
                            textAlign: TextAlign.justify),
                        onTap: () {
                          Share.shareFiles(
                            [list[index].absolute.path],
                            subject:
                                "Laporan Rekap Kehadiran ${listBulan[indexBulan]} $tahun",
                          );
                        }),
                  );
                },
              );
            } else {
              return Container();
            }
          }),
    );
  }
}
