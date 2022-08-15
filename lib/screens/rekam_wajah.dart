import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class RekamWajah extends StatefulWidget {
  const RekamWajah({Key? key}) : super(key: key);

  @override
  State<RekamWajah> createState() => _RekamWajahState();
}

class _RekamWajahState extends State<RekamWajah> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );

    initialized();
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  List<Face>? faces;
  bool loading = false;
  CameraController? controller;
  CameraDescription? description;
  CameraLensDirection lensDirection = CameraLensDirection.front;
  FaceDetector? faceDetector;
  dynamic result;
  bool isLoading = false;

  Future<void> initCamera() async {
    List<CameraDescription> cameras = await availableCameras();
    CameraDescription camera =
        cameras.firstWhere((cam) => cam.lensDirection == lensDirection);
    CameraController cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await cameraController.initialize();

    if (mounted) {
      setState(() {
        controller = cameraController;
        description = camera;
      });
    }
  }

  initFaceDetector() {
    setState(() {
      faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableTracking: true,
        ),
      );
    });
  }

  frameFaces() {
    controller!.startImageStream((CameraImage image) async {
      InputImageData inputImageData = InputImageData(
        imageRotation:
            rotationIntToImageRotation(description!.sensorOrientation),
        inputImageFormat: InputImageFormat.nv21,
        size: Size(image.width.toDouble(), image.height.toDouble()),
        planeData: image.planes.map(
          (Plane plane) {
            return InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              width: plane.width,
              height: plane.height,
            );
          },
        ).toList(),
      );

      InputImage inputImage = InputImage.fromBytes(
        bytes: concatenatePlanes(image.planes),
        inputImageData: inputImageData,
      );

      if (faceDetector != null) {
        final face = await faceDetector!.processImage(inputImage);
        if (mounted) {
          setState(() {
            faces = face;
          });
        }
      }
    });
  }

  initialized() async {
    await initCamera();
    // initFaceDetector();
    // await frameFaces();
  }

  void toggleCameraDirection() {
    if (controller != null) {
      CameraLensDirection direction = controller!.description.lensDirection;

      if (direction == CameraLensDirection.front) {
        setState(() {
          lensDirection = CameraLensDirection.back;
        });
      } else {
        setState(() {
          lensDirection = CameraLensDirection.front;
        });
      }

      setState(() {
        faces = null;
        faceDetector = null;
      });
      initialized();
    }
  }

  InputImageRotation rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  int cameraUsed() {
    return lensDirection == CameraLensDirection.front ? 1 : 0;
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rekam Wajah"),
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: controller == null
            ? Container(
                padding: const EdgeInsets.all(10),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: const Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(),
                  ),
                ))
            : Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width *
                        controller!.value.aspectRatio,
                    child: CameraPreview(controller!),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width *
                        controller!.value.aspectRatio,
                    child: controller != null && faces != null
                        ? CustomPaint(
                            painter: DetectorPainter(
                              Size(
                                controller!.value.previewSize!.width,
                                controller!.value.previewSize!.width,
                              ),
                              faces!,
                              controller!.description.lensDirection,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: cameraUsed(),
        onTap: (value) {
          toggleCameraDirection();
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_rear),
            label: "Kamera Belakang",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_front),
            label: "Kamera Depan",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera),
        onPressed: () async {
          if (controller != null && isLoading == false) {
            try {
              controller!.setFlashMode(FlashMode.off);
              // controller!.stopImageStream();
              // await Future.delayed(const Duration(milliseconds: 500));
              final XFile capture = await controller!.takePicture();

              if (mounted) {
                Navigator.pop(context, File(capture.path));
              }
            } on CameraException catch (err) {
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(err.description!)));
            }
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class DetectorPainter extends CustomPainter {
  final CameraLensDirection direction;
  final Size image;
  final List<Face> faces;
  final List<Rect> rects = <Rect>[];

  DetectorPainter(this.image, this.faces, this.direction) {
    for (var i = 0; i < faces.length; i++) {
      rects.add(faces[i].boundingBox);
    }
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final scaleX = size.width / image.width;
    final scaleY = size.height / image.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (var i = 0; i < faces.length; i++) {
      final Rect rect = rects[i];
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left * scaleX + 30,
          rect.top * scaleY - 10,
          direction == CameraLensDirection.back
              ? (rect.right * scaleX) * 2 - 15
              : (rect.right * scaleX) * 2 - 20,
          rect.bottom * scaleY + 10,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DetectorPainter oldDelegate) {
    return image != oldDelegate.image || faces != oldDelegate.faces;
  }
}
