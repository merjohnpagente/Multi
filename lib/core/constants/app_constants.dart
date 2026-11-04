class AppConstants {
  AppConstants._();

  static const String appName = 'Photo Organizer';
  static const String appTagline = 'Organize. Find. Discover.';
  static const String appVersion = '1.0.0';

  static const String databaseName = 'photo_organizer.db';
  static const int databaseVersion = 1;

  static const int pageSize = 100;
  static const int thumbnailSize = 320;
  static const int gridThumbnailSize = 500;

  static const String generalModelAsset = 'assets/models/image_classifier.tflite';
  static const String generalLabelsAsset = 'assets/models/image_labels.txt';
  static const String plantModelAsset = 'assets/models/plant_classifier.tflite';
  static const String plantLabelsAsset = 'assets/models/plant_labels.txt';
  static const String birdModelAsset = 'assets/models/bird_classifier.tflite';
  static const String birdLabelsAsset = 'assets/models/bird_labels.txt';

  static const int currentAnalysisVersion = 1;

  static const double defaultConfidenceThreshold = 0.35;
  static const int defaultSessionLimit = 120;
  static const int defaultGridColumns = 3;
  static const int duplicateHammingThreshold = 8;
  static const int maxTopLabels = 5;
}
