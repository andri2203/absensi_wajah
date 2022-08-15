import 'package:flutter/material.dart';
import 'package:date_time_picker/date_time_picker.dart';

import '../resource/absensi.dart';
import '../resource/mahasiswa.dart';
import '../utils/date_time.dart';

class Presensi extends StatefulWidget {
  const Presensi({Key? key}) : super(key: key);

  @override
  State<Presensi> createState() => _PresensiState();
}

class _PresensiState extends State<Presensi> {
  TableAbsensi tbAbsensi = TableAbsensi();
  TableMahasiswa tbMahasiswa = TableMahasiswa();
  List<Map<String, Object?>> dataMahasiswa = [];
  List<Absensi?> dataAbsensi = [];
  Absensi? absensi;
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
  bool isSearch = false;

  @override
  void initState() {
    super.initState();
    getDataMahasiswa();
  }

  Future<void> getDataAbsensi() async {
    List<Absensi?> maps = [];
    maps = await tbAbsensi.getOneDayOnly(startEpochTime, endEpochTime);
    setState(() {
      dataAbsensi = maps;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Absensi"),
      ),
      body: Container(
        padding: const EdgeInsets.all(10),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            picker(
              dateLabelText: "Tanggal Mulai",
              timeLabelText: "Jam Mulai",
              status: "start",
              onChanged: (val) {
                setState(() {
                  startEpochTime = DateTime.parse(val!).millisecondsSinceEpoch;
                });
              },
            ),
            picker(
              dateLabelText: "Tanggal Akhir",
              timeLabelText: "Jam Akhir",
              status: "end",
              onChanged: (val) {
                setState(() {
                  endEpochTime =
                      DateTime.parse("$val:59").millisecondsSinceEpoch;
                });
              },
            ),
            buttonSearch(),
            const Divider(),
            if (isSearch)
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
        ),
      ),
    );
  }

  Container buttonSearch() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
              onPressed: () {
                if (startEpochTime == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Silahkan Pilih Tanggal Mulai")));
                  return;
                }

                if (endEpochTime == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Silahkan Pilih Tanggal Akhir")));
                  return;
                }
                getDataAbsensi();
                setState(() {
                  isSearch = true;
                });
              },
              icon: const Icon(Icons.search),
              label: const Text("Cari Data")),
        ],
      ),
    );
  }

  DateTimePicker picker({
    String? dateLabelText,
    String? timeLabelText,
    String status = "start",
    void Function(String?)? onChanged,
  }) {
    Map<String, int> date = startEndDay(DateTime.now());
    return DateTimePicker(
      type: DateTimePickerType.dateTimeSeparate,
      dateMask: 'd MMM, yyyy',
      initialValue:
          DateTime.fromMillisecondsSinceEpoch(date[status]!).toString(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      icon: const Icon(Icons.event),
      dateLabelText: dateLabelText,
      timeLabelText: timeLabelText,
      selectableDayPredicate: (date) {
        // Disable weekend days to select from the calendar
        if (date.weekday == 6 || date.weekday == 7) {
          return false;
        }

        return true;
      },
      onChanged: onChanged,
      validator: (val) {
        return null;
      },
    );
  }

  Widget dataBuilder() {
    return ListView.builder(
      itemCount: dataAbsensi.length,
      itemBuilder: (context, index) {
        return dataList(context, dataAbsensi[index]);
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
}
