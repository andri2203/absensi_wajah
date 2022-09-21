import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:date_time_picker/date_time_picker.dart';

import '../firebase/firestore.dart';
import '../resource/absensi.dart';
import '../resource/mahasiswa.dart';
import '../utils/date_time.dart';

class Presensi extends StatefulWidget {
  const Presensi({Key? key}) : super(key: key);

  @override
  State<Presensi> createState() => _PresensiState();
}

class _PresensiState extends State<Presensi> {
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

  Future<void> getDataAbsensi() async {
    refAbsensi
        .where("masuk", isGreaterThan: startEpochTime)
        .where("masuk", isLessThan: endEpochTime)
        .where("kodeMK", isEqualTo: mk)
        .orderBy("masuk", descending: true)
        .get()
        .then((snap) {
      List<Absensi?> maps = [];
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs;
      for (var i = 0; i < docs.length; i++) {
        QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[i];
        maps.add(Absensi.fromFirestore(doc.data(), doc.id));
      }
      setState(() {
        dataAbsensi = maps;
      });
    }).onError((error, _) {
      scaffold.currentState!.showSnackBar(SnackBar(content: Text("$error")));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffold,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Data Absensi"),
        ),
        body: Container(
          padding: const EdgeInsets.all(10),
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(
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
              picker(
                dateLabelText: "Tanggal Mulai",
                timeLabelText: "Jam Mulai",
                status: "start",
                onChanged: (val) {
                  setState(() {
                    startEpochTime =
                        DateTime.parse(val!).millisecondsSinceEpoch;
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
              Expanded(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  padding: const EdgeInsets.only(bottom: 10, top: 5),
                  child: userStream(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget userStream() {
    return StreamBuilder<QuerySnapshot<Map<String, Object?>>>(
      stream: refUsers
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

        return ListView.builder(
          itemCount: snapshot1.data!.docs.length,
          itemBuilder: (context, index1) {
            QueryDocumentSnapshot<Map<String, Object?>> dtUser =
                snapshot1.data!.docs[index1];
            Mahasiswa mhs = Mahasiswa.fromFirestoreMap(
                dtUser.id, dtUser.data()["info"] as Map<String, Object?>);
            DateTime st = DateTime.fromMillisecondsSinceEpoch(startEpochTime);
            DateTime en = DateTime.fromMillisecondsSinceEpoch(endEpochTime);
            List<Absensi?> listAbsen =
                dataAbsensi.where((el) => el!.userID == mhs.uid).toList();
            int between = en.difference(st).inDays + 1;
            int dataCount = listAbsen.length;
            List<String> tgl = List.generate(between, (index) {
              int day = st.day + index;
              return "$day/${st.month}/${st.year}";
            });
            return Card(
              child: ListTile(
                title: Text(mhs.nama!),
                subtitle: Text(
                  "Lihat Data Absensi",
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.blue.shade300),
                ),
                trailing: Text(mk == "pilih"
                    ? "Silahkan Pilih Mata Kuliah"
                    : "Masuk $dataCount, Alpa ${between - dataCount}"),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(mk),
                        scrollable: true,
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: tgl.map((val) {
                              String jamMasuk = "";
                              String jamKeluar = "";
                              for (var i = 0; i < listAbsen.length; i++) {
                                Absensi? dt = listAbsen[i];
                                DateTime masuk =
                                    DateTime.fromMillisecondsSinceEpoch(
                                        dt!.masuk!);
                                DateTime keluar =
                                    DateTime.fromMillisecondsSinceEpoch(
                                        dt.keluar!);
                                String tanggal =
                                    "${masuk.day}/${masuk.month}/${masuk.year}";
                                if (tanggal == val) {
                                  jamMasuk = dateTime(masuk, disabledDay: true);
                                  jamKeluar = dt.keluar == 0
                                      ? ""
                                      : dateTime(keluar, disabledDay: true);
                                }
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: Text("$val: $jamMasuk - $jamKeluar"),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
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
                if (mk == "pilih") {
                  scaffold.currentState!.showSnackBar(const SnackBar(
                      content: Text("Silahkan Pilih Mata Kuliah")));
                  return;
                }

                if (startEpochTime == 0) {
                  scaffold.currentState!.showSnackBar(const SnackBar(
                      content: Text("Silahkan Pilih Tanggal Mulai")));
                  return;
                }

                if (endEpochTime == 0) {
                  scaffold.currentState!.showSnackBar(const SnackBar(
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

  Widget picker({
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
      // selectableDayPredicate: (date) {
      //   // Disable weekend days to select from the calendar
      //   if (date.weekday == 6 || date.weekday == 7) {
      //     return false;
      //   }

      //   return true;
      // },
      onChanged: onChanged,
      validator: (val) {
        return null;
      },
    );
  }
}
