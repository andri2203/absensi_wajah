import 'package:absensi_wajah/firebase/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class MataKuliah extends StatefulWidget {
  const MataKuliah({Key? key}) : super(key: key);

  @override
  State<MataKuliah> createState() => _MataKuliahState();
}

class _MataKuliahState extends State<MataKuliah> {
  CollectionReference<Map<String, dynamic>> ref =
      FirestoreDatabase.collection("mataKuliah");
  final TextEditingController kode = TextEditingController();
  final TextEditingController matkul = TextEditingController();
  final TextEditingController masuk = TextEditingController();
  final TextEditingController dispensasi = TextEditingController();
  late TimeOfDay jamMasuk;
  final GlobalKey<FormState> form = GlobalKey<FormState>();
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

  addData() {
    if (form.currentState != null && form.currentState!.validate()) {
      ref.doc(kode.text).set({
        "matkul": matkul.text,
        "jam_masuk": {
          "jam": jamMasuk.hour,
          "menit": jamMasuk.minute,
        },
        "dispensasi": int.parse(dispensasi.text),
      }).then(
        (value) {
          setState(() {
            kode.text = "";
            matkul.text = "";
            masuk.text = "";
            dispensasi.text = "";
          });
          return ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Berhasil Menambah Matkul Baru"),
          ));
        },
      ).catchError(
        (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal: $error"),
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mata Kuliah"),
      ),
      body: Container(
          padding: const EdgeInsets.all(8.0),
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Flex(direction: Axis.vertical, children: [
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: form,
                  child: Column(
                    children: [
                      _textField(
                          controller: kode,
                          regexNoSpace: true,
                          label: "Kode Matkul"),
                      _textField(controller: matkul, label: "Nama Matkul"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _textField(
                                controller: masuk,
                                label: "Jam Masuk",
                                readOnly: true,
                                onTap: () {
                                  showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  ).then((time) {
                                    if (time != null) {
                                      setState(() {
                                        jamMasuk = time;
                                        masuk.text =
                                            '${time.hour.toString().length > 1 ? time.hour : "0${time.hour}"}:${time.minute.toString().length > 1 ? time.minute : "0${time.minute}"}';
                                      });
                                    }
                                  });
                                }),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Flexible(
                            child: _textField(
                              controller: dispensasi,
                              label: "Dispensasi (Menit)",
                              prefixLabelActive: false,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        ElevatedButton(
                            onPressed: addData,
                            child: const Text("Tambah Matkul")),
                      ])
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.none) {
                  return const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snap.data == null || snap.data!.docs.isEmpty) {
                  return const Expanded(
                    child: Center(
                      child: Text("Data Tidak Ditemukan"),
                    ),
                  );
                }
                return Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: snap.data!.docs.map(
                      (data) {
                        var d = data.data();
                        TimeOfDay time = TimeOfDay(
                          hour: d["jam_masuk"]["jam"],
                          minute: d["jam_masuk"]['menit'],
                        );
                        TimeOfDay dispen = time.replacing(
                          hour: time.hour,
                          minute: time.minute + d["dispensasi"] as int,
                        );
                        return Card(
                          child: Slidable(
                            startActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (context) {},
                                    backgroundColor: const Color(0xFFFE4A49),
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Hapus',
                                  ),
                                  SlidableAction(
                                    onPressed: (context) {},
                                    backgroundColor: const Color(0xFF35CA21),
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit,
                                    label: 'Ubah',
                                  ),
                                ]),
                            child: ListTile(
                              title: Text(data.id),
                              dense: true,
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${d["matkul"]}"),
                                    Text("Jam Masuk : ${time.format(context)}"),
                                    Text(
                                        "Batas Masuk : ${dispen.format(context)}"),
                                  ]),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                );
              },
            ),
          ])),
    );
  }

  Widget _textField({
    required String label,
    bool enabled = true,
    bool readOnly = false,
    bool prefixLabelActive = true,
    String? value,
    TextEditingController? controller,
    void Function()? onTap,
    TextInputType? keyboardType,
    // Validator
    bool notNull = true,
    bool regexNoSpace = false,
    int minLengthValues = 1,
  }) {
    String? validator(String? text) {
      final regexNoSpacing = RegExp(r'^[a-zA-Z0-9_\-=@,\.;]+$');

      if (notNull && text == null || text!.isEmpty) {
        return "$label Tidak Boleh Kosong";
      }

      if (keyboardType == TextInputType.number) {
        if (int.parse(text) > 10) {
          return "Tidak Boleh Lebih 10 Menit";
        }
      }

      if (text.length < minLengthValues) {
        return "Jumlah Karakter $label harus lebih dari $minLengthValues";
      }

      if (regexNoSpace && !regexNoSpacing.hasMatch(text)) {
        return "Karakter $label harus berupa Huruf, Angka dan tidak ada Spasi.";
      }

      return null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        controller: controller,
        enabled: enabled,
        initialValue: value,
        validator: validator,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(6),
          hintText: label,
          icon: prefixLabelActive
              ? SizedBox(
                  width: MediaQuery.of(context).size.width / 6,
                  child: Text(label),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
