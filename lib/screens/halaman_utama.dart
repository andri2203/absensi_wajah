import 'dart:io';

import 'package:absensi_wajah/screens/rekam_wajah.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  File? imageFile;
  List<Face>? faces;
  ui.Image? image;
  Size sizeImg = const Size(300, 400);

  Future handleAbsenMasuk(BuildContext context) async {
    final files = (await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const RekamWajah(),
      ),
    ));
    setState(() {
      imageFile = files;
      _loadImage(files);
    });
    if (imageFile != null && files != null) {
      final image = InputImage.fromFile(files);
      final faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final face = await faceDetector.processImage(image);

      if (mounted) {
        setState(() {
          faces = face;
        });
      }
    }
  }

  Size imageSized(BuildContext context) {
    return Size(MediaQuery.of(context).size.width - 240,
        MediaQuery.of(context).size.width - 200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      drawer: const Drawer(),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(15),
          elevation: 5,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: imageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          onPressed: () => handleAbsenMasuk(context),
                          child: const Text("Absen Masuk")),
                      ElevatedButton(
                          onPressed: () => {},
                          child: const Text("Absen Keluar")),
                    ],
                  )
                : Column(
                    children: [
                      Center(
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
                      ),
                      Container(
                        margin: const EdgeInsets.only(
                            bottom: 7, left: 20, right: 20),
                        width: imageSized(context).width,
                        height: imageSized(context).height,
                        color: Colors.grey[200],
                        child: Image.file(
                          height: image!.height - (image!.height * 0.3),
                          imageFile!,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              RichText(
                                text: const TextSpan(
                                  text: "R Andri Pratama",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => handleAbsenMasuk(context),
                        child: const Text("Rekam Ulang"),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  _loadImage(File? file) async {
    if (file != null) {
      final data = await file.readAsBytes();
      await decodeImageFromList(data).then((value) {
        setState(() {
          image = value;
        });
      });
    }
  }
}
