import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

Future<tfl.Interpreter?> loadModel() async {
  try {
    final gpuDelegateV2 = tfl.GpuDelegateV2(
        options: tfl.GpuDelegateOptionsV2(
            isPrecisionLossAllowed: false,
            inferencePreference: tfl.TfLiteGpuInferenceUsage.fastSingleAnswer,
            inferencePriority1: tfl.TfLiteGpuInferencePriority.minMemoryUsage,
            inferencePriority2: tfl.TfLiteGpuInferencePriority.minLatency,
            inferencePriority3: tfl.TfLiteGpuInferencePriority.auto,
            maxDelegatePartitions: 1));

    var interpreterOptions = tfl.InterpreterOptions()
      ..addDelegate(gpuDelegateV2);
    return await tfl.Interpreter.fromAsset('mobilefacenet.tflite',
        options: interpreterOptions);
  } on Exception {
    // ignore: avoid_print
    print('Failed to load model.');
    return null;
  }
}
