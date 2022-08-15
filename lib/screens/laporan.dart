import 'package:flutter/material.dart';

class Laporan extends StatefulWidget {
  const Laporan({Key? key}) : super(key: key);

  @override
  State<Laporan> createState() => _LaporanState();
}

class _LaporanState extends State<Laporan> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton(
                  value: now.month - 1,
                  items: listBulan
                      .map<DropdownMenuItem<int>>(
                          (val) => DropdownMenuItem<int>(
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
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  label: const Text("Lihat"),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
