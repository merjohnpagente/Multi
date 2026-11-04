
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../shared/models/ai_models.dart';
import '../../shared/models/app_category.dart';
import '../constants/app_constants.dart';
import '../utilities/formatters.dart';
import '../utilities/label_taxonomy.dart';
import '../utilities/slug_utils.dart';

class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiService {
  AiService();

  static const MethodChannel _visionChannel =
      MethodChannel('photo_organizer/vision');

  _TfliteClassifier? _general;
  _TfliteClassifier? _plants;
  _TfliteClassifier? _birds;
  Future<_TfliteClassifier>? _generalLoading;
  Future<_TfliteClassifier>? _plantsLoading;
  Future<_TfliteClassifier>? _birdsLoading;
  bool _disposed = false;

  bool get isReady => _general != null;

  Future<void> preloadGeneral() async {
    await _loadGeneral();
  }

  Future<void> preloadAll() async {
    await Future.wait(<Future<void>>[
      _loadGeneral().then((_) {}),
      _loadPlants().then((_) {}),
      _loadBirds().then((_) {}),
    ]);
  }

  Future<int> _detectFaces(Uint8List bytes) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 0;
    }
    try {
      final int? count = await _visionChannel.invokeMethod<int>(
        'detectFaces',
        <String, dynamic>{'bytes': bytes},
      );
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<_TfliteClassifier> _loadGeneral() {
    if (_general != null) {
      return Future<_TfliteClassifier>.value(_general);
    }
    return _generalLoading ??= _TfliteClassifier.load(
      modelAsset: AppConstants.generalModelAsset,
      labelsAsset: AppConstants.generalLabelsAsset,
      name: 'Image classifier',
    ).then((_TfliteClassifier classifier) {
      _general = classifier;
      return classifier;
    });
  }

  Future<_TfliteClassifier> _loadPlants() {
    if (_plants != null) {
      return Future<_TfliteClassifier>.value(_plants);
    }
    return _plantsLoading ??= _TfliteClassifier.load(
      modelAsset: AppConstants.plantModelAsset,
      labelsAsset: AppConstants.plantLabelsAsset,
      name: 'Plant classifier',
    ).then((_TfliteClassifier classifier) {
      _plants = classifier;
      return classifier;
    });
  }

  Future<_TfliteClassifier> _loadBirds() {
    if (_birds != null) {
      return Future<_TfliteClassifier>.value(_birds);
    }
    return _birdsLoading ??= _TfliteClassifier.load(
      modelAsset: AppConstants.birdModelAsset,
      labelsAsset: AppConstants.birdLabelsAsset,
      name: 'Bird classifier',
    ).then((_TfliteClassifier classifier) {
      _birds = classifier;
      return classifier;
    });
  }

  Future<AiIdentification> classifyBytes(
    Uint8List bytes, {
    required double confidenceThreshold,
    bool thorough = false,
    String extension = 'jpg',
  }) async {
    if (_disposed) {
      throw AiException('The AI engine is no longer available.');
    }
    if (bytes.isEmpty) {
      throw AiException('The selected image is empty.');
    }

    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw AiException(
        'This image format is not supported. Try a JPG, PNG or WEBP photo.',
      );
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    final _TfliteClassifier general = await _loadGeneral();
    final List<_Prediction> generalTop = general.predict(decoded, topK: 7);
    if (generalTop.isEmpty) {
      throw AiException('The AI model could not read this image.');
    }

    final int faceCount = await _detectFaces(bytes);
    if (faceCount > 0) {
      stopwatch.stop();
      final String subject = faceCount == 1
          ? 'one person'
          : '$faceCount people';
      return AiIdentification(
        primaryLabel: 'Person',
        category: AppCategory.people,
        subcategory: faceCount == 1 ? 'Portraits' : 'Groups',
        confidence: 0.96,
        description:
            'On-device face detection found $subject in this photo. '
            'It was sorted into People without uploading the image.',
        suggestedFilename: suggestedFilename('Person', extension),
        labels: const <LabelScore>[
          LabelScore(label: 'Person', confidence: 0.96, source: 'face'),
        ],
        uncertain: false,
        inferenceMs: stopwatch.elapsedMilliseconds,
      );
    }

    final List<_Prediction> generalLabels =
        generalTop.take(AppConstants.maxTopLabels).toList(growable: false);
    final List<LabelInfo> generalInfos = generalLabels.map(
      (_Prediction prediction) => LabelTaxonomy.describe(
        prediction.label,
        source: 'general',
      ),
    ).toList(growable: false);

    final bool plantHint = generalLabels.any(
      (_Prediction prediction) => LabelTaxonomy.isPlantHint(prediction.label),
    ) ||
        generalInfos.any(
          (LabelInfo info) =>
              info.category == AppCategory.plants ||
              info.category == AppCategory.nature,
        );
    final bool birdHint = generalLabels.any(
          (_Prediction prediction) =>
              LabelTaxonomy.isBirdHint(prediction.label),
        ) ||
        generalInfos.any(
          (LabelInfo info) =>
              info.category == AppCategory.animals &&
              info.subcategory == 'Birds',
        );

    final List<_Prediction> plantTop = <_Prediction>[];
    final List<_Prediction> birdTop = <_Prediction>[];
    if (thorough || plantHint) {
      final _TfliteClassifier plants = await _loadPlants();
      plantTop.addAll(plants.predict(decoded, topK: 4));
    }
    if (thorough || birdHint) {
      final _TfliteClassifier birds = await _loadBirds();
      birdTop.addAll(birds.predict(decoded, topK: 4));
    }

    final List<_Prediction> predictions = <_Prediction>[
      ...generalLabels,
      ...plantTop.take(2),
      ...birdTop.take(2),
    ];

    _Prediction primary = generalTop.first;
    String primarySource = 'general';
    final _Prediction? plantCandidate = plantTop.isEmpty ? null : plantTop.first;
    final _Prediction? birdCandidate = birdTop.isEmpty ? null : birdTop.first;

    final bool choosePlant = plantCandidate != null &&
        plantCandidate.confidence >= confidenceThreshold &&
        (plantHint || plantCandidate.confidence > primary.confidence);
    final bool chooseBird = birdCandidate != null &&
        birdCandidate.confidence >= confidenceThreshold &&
        (birdHint || birdCandidate.confidence > primary.confidence);

    if (choosePlant && (!chooseBird || plantCandidate.confidence >= birdCandidate.confidence)) {
      primary = plantCandidate;
      primarySource = 'plant';
    } else if (chooseBird) {
      primary = birdCandidate;
      primarySource = 'bird';
    }

    final LabelInfo primaryInfo = LabelTaxonomy.describe(
      primary.label,
      source: primarySource,
    );
    final bool uncertain = primary.confidence < confidenceThreshold ||
        (primaryInfo.category == AppCategory.other &&
            primary.confidence < confidenceThreshold * 1.4);

    final List<LabelScore> labelScores = <LabelScore>[];
    final Set<String> seen = <String>{};
    for (final _Prediction prediction in predictions) {
      final String key = prediction.label.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      labelScores.add(
        LabelScore(
          label: prediction.label,
          confidence: prediction.confidence,
          source: prediction.source,
        ),
      );
    }
    labelScores.sort(
      (LabelScore a, LabelScore b) => b.confidence.compareTo(a.confidence),
    );

    final List<String> alternates = labelScores
        .where((LabelScore label) =>
            label.label.toLowerCase() != primary.label.toLowerCase())
        .take(3)
        .map((LabelScore label) => humanizeLabel(label.label))
        .toList(growable: false);

    final String displayName = primaryInfo.displayName;
    final String description = _buildDescription(
      displayName: displayName,
      info: primaryInfo,
      confidence: primary.confidence,
      uncertain: uncertain,
      alternates: alternates,
    );

    stopwatch.stop();
    return AiIdentification(
      primaryLabel: displayName,
      category: primaryInfo.category,
      subcategory: primaryInfo.subcategory,
      confidence: primary.confidence,
      description: description,
      suggestedFilename: suggestedFilename(displayName, extension),
      labels: labelScores.take(AppConstants.maxTopLabels).toList(growable: false),
      uncertain: uncertain,
      inferenceMs: stopwatch.elapsedMilliseconds,
    );
  }

  String _buildDescription({
    required String displayName,
    required LabelInfo info,
    required double confidence,
    required bool uncertain,
    required List<String> alternates,
  }) {
    final String percent = formatPercent(confidence);
    final StringBuffer buffer = StringBuffer();
    if (uncertain) {
      buffer.write(
        'Low-confidence on-device result. The closest match is '
        '"$displayName" in ${info.category.label} · ${info.subcategory} '
        '($percent confidence).',
      );
    } else {
      buffer.write(
        'On-device AI identified "$displayName" '
        '(${info.category.label} · ${info.subcategory}) '
        'with $percent confidence.',
      );
    }
    if (alternates.isNotEmpty) {
      buffer.write(' Related matches: ${alternates.join(', ')}.');
    }
    buffer.write(' No image data left this device.');
    return buffer.toString();
  }

  void dispose() {
    _disposed = true;
    _general?.dispose();
    _plants?.dispose();
    _birds?.dispose();
    _general = null;
    _plants = null;
    _birds = null;
  }
}

class _Prediction {
  const _Prediction({
    required this.label,
    required this.confidence,
    required this.source,
  });

  final String label;
  final double confidence;
  final String source;
}

class _TfliteClassifier {
  _TfliteClassifier({
    required this.interpreter,
    required this.options,
    required this.labels,
    required this.name,
  });

  final Interpreter interpreter;
  final InterpreterOptions options;
  final List<String> labels;
  final String name;

  static Future<_TfliteClassifier> load({
    required String modelAsset,
    required String labelsAsset,
    required String name,
  }) async {
    final String rawLabels = await rootBundle.loadString(labelsAsset);
    final List<String> labels = rawLabels
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) {
      throw AiException('The label file for $name is missing or empty.');
    }
    final InterpreterOptions options = InterpreterOptions()..threads = 2;
    try {
      final Interpreter interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: options,
      );
      return _TfliteClassifier(
        interpreter: interpreter,
        options: options,
        labels: labels,
        name: name,
      );
    } catch (error) {
      options.delete();
      if (kDebugMode) {
        debugPrint('Failed to load $name: $error');
      }
      throw AiException(
        'The offline $name model could not be loaded. '
        'Verify the model asset is bundled in the APK.',
      );
    }
  }

  List<_Prediction> predict(img.Image source, {int topK = 5}) {
    final Tensor inputTensor = interpreter.getInputTensor(0);
    final List<int> inputShape = inputTensor.shape;
    if (inputShape.length < 4) {
      throw AiException('The $name model has an unsupported input shape.');
    }
    final int inputSize = inputShape[inputShape.length - 3];
    final img.Image resized = img.copyResize(
      img.bakeOrientation(source),
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
    final Uint8List rgb =
        resized.getBytes(order: img.ChannelOrder.rgb);

    final Tensor outputTensor = interpreter.getOutputTensor(0);
    final int outputCount =
        outputTensor.numElements() > 0
            ? outputTensor.numElements()
            : labels.length;

    List<double> scores;
    if (outputTensor.type == TensorType.uint8 ||
        outputTensor.type == TensorType.int8) {
      final Uint8List rawOutput = Uint8List(outputCount);
      Object input;
      if (inputTensor.type == TensorType.uint8) {
        input = rgb;
      } else if (inputTensor.type == TensorType.float32) {
        input = _rgbToFloatList(rgb, inputSize);
      } else {
        throw AiException(
          'The $name model input type is not supported on this build.',
        );
      }
      interpreter.run(input, rawOutput);
      final double scale = outputTensor.params.scale;
      final int zero = outputTensor.params.zeroPoint;
      final bool signed = outputTensor.type == TensorType.int8;
      scores = List<double>.generate(outputCount, (int index) {
        final int raw = signed
            ? rawOutput[index].toSigned(8)
            : rawOutput[index];
        return (raw - zero) * scale;
      });
    } else if (outputTensor.type == TensorType.float32) {
      final List<List<double>> rawOutput = List<List<double>>.generate(
        1,
        (_) => List<double>.filled(outputCount, 0),
      );
      Object input;
      if (inputTensor.type == TensorType.uint8) {
        input = rgb;
      } else if (inputTensor.type == TensorType.float32) {
        input = _rgbToFloatList(rgb, inputSize);
      } else {
        throw AiException(
          'The $name model input type is not supported on this build.',
        );
      }
      interpreter.run(input, rawOutput);
      scores = rawOutput.first;
    } else {
      throw AiException(
        'The $name model output type is not supported on this build.',
      );
    }

    final int count = scores.length < labels.length ? scores.length : labels.length;
    if (count == 0) {
      return const <_Prediction>[];
    }
    final List<int> indices = List<int>.generate(count, (int index) => index)
      ..sort((int a, int b) => scores[b].compareTo(scores[a]));

    final List<_Prediction> predictions = <_Prediction>[];
    for (final int index in indices) {
      final String label = labels[index];
      if (label.toLowerCase().contains('background')) {
        continue;
      }
      final double confidence = scores[index].clamp(0, 1).toDouble();
      if (confidence <= 0) {
        continue;
      }
      predictions.add(
        _Prediction(
          label: label,
          confidence: confidence,
          source: _sourceForName(name),
        ),
      );
      if (predictions.length >= topK) {
        break;
      }
    }
    return predictions;
  }

  String _sourceForName(String modelName) {
    if (modelName.toLowerCase().contains('plant')) {
      return 'plant';
    }
    if (modelName.toLowerCase().contains('bird')) {
      return 'bird';
    }
    return 'general';
  }

  List<List<List<List<double>>>> _rgbToFloatList(Uint8List rgb, int size) {
    final List<List<List<List<double>>>> output =
        List<List<List<List<double>>>>.generate(
      1,
      (_) => List<List<List<double>>>.generate(
        size,
        (int y) => List<List<double>>.generate(
          size,
          (int x) {
            final int offset = (y * size + x) * 3;
            return <double>[
              (rgb[offset] - 127.5) / 127.5,
              (rgb[offset + 1] - 127.5) / 127.5,
              (rgb[offset + 2] - 127.5) / 127.5,
            ];
          },
        ),
      ),
    );
    return output;
  }

  void dispose() {
    interpreter.close();
    options.delete();
  }
}
