import 'ai_models.dart';
import 'app_category.dart';

class PhotoRecord {
  const PhotoRecord({
    required this.assetId,
    required this.title,
    required this.width,
    required this.height,
    required this.mimeType,
    required this.fileSize,
    required this.createDate,
    required this.modifiedDate,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.primaryLabel,
    required this.subcategory,
    required this.confidence,
    required this.labelsJson,
    required this.analyzedAt,
    required this.organizedAt,
    required this.cameraMake,
    required this.cameraModel,
    required this.analysisVersion,
  });

  final String assetId;
  final String title;
  final int width;
  final int height;
  final String? mimeType;
  final int fileSize;
  final DateTime createDate;
  final DateTime modifiedDate;
  final double? latitude;
  final double? longitude;
  final AppCategory category;
  final String? primaryLabel;
  final String? subcategory;
  final double? confidence;
  final String? labelsJson;
  final DateTime? analyzedAt;
  final DateTime? organizedAt;
  final String? cameraMake;
  final String? cameraModel;
  final int analysisVersion;

  bool get isAnalyzed => analyzedAt != null;
  bool get hasLocation => latitude != null && longitude != null;
  bool get isLowConfidence => (confidence ?? 0) < 0.35;

  List<LabelScore> get labels => LabelScore.fromJson(labelsJson);

  double get aspectRatio {
    if (width <= 0 || height <= 0) {
      return 1;
    }
    return width / height;
  }

  String get resolutionLabel => '$width × $height';

  String get formatLabel {
    final String? type = mimeType;
    if (type != null && type.contains('/')) {
      return type.split('/').last.toUpperCase();
    }
    final int dot = title.lastIndexOf('.');
    if (dot >= 0 && dot < title.length - 1) {
      return title.substring(dot + 1).toUpperCase();
    }
    return 'IMAGE';
  }

  PhotoRecord copyWith({
    String? title,
    int? width,
    int? height,
    String? mimeType,
    int? fileSize,
    DateTime? createDate,
    DateTime? modifiedDate,
    double? latitude,
    double? longitude,
    AppCategory? category,
    String? primaryLabel,
    String? subcategory,
    double? confidence,
    String? labelsJson,
    DateTime? analyzedAt,
    DateTime? organizedAt,
    String? cameraMake,
    String? cameraModel,
    int? analysisVersion,
  }) {
    return PhotoRecord(
      assetId: assetId,
      title: title ?? this.title,
      width: width ?? this.width,
      height: height ?? this.height,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createDate: createDate ?? this.createDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      primaryLabel: primaryLabel ?? this.primaryLabel,
      subcategory: subcategory ?? this.subcategory,
      confidence: confidence ?? this.confidence,
      labelsJson: labelsJson ?? this.labelsJson,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      organizedAt: organizedAt ?? this.organizedAt,
      cameraMake: cameraMake ?? this.cameraMake,
      cameraModel: cameraModel ?? this.cameraModel,
      analysisVersion: analysisVersion ?? this.analysisVersion,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'asset_id': assetId,
        'title': title,
        'width': width,
        'height': height,
        'mime_type': mimeType,
        'file_size': fileSize,
        'create_date': createDate.millisecondsSinceEpoch,
        'modified_date': modifiedDate.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'category': category.name,
        'primary_label': primaryLabel,
        'subcategory': subcategory,
        'confidence': confidence,
        'labels_json': labelsJson,
        'analyzed_at': analyzedAt?.millisecondsSinceEpoch,
        'organized_at': organizedAt?.millisecondsSinceEpoch,
        'camera_make': cameraMake,
        'camera_model': cameraModel,
        'analysis_version': analysisVersion,
      };

  factory PhotoRecord.fromMap(Map<String, Object?> map) {
    final int create = (map['create_date'] as num?)?.toInt() ?? 0;
    final int modified = (map['modified_date'] as num?)?.toInt() ?? create;
    final int? analyzed = (map['analyzed_at'] as num?)?.toInt();
    final int? organized = (map['organized_at'] as num?)?.toInt();
    return PhotoRecord(
      assetId: map['asset_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      mimeType: map['mime_type'] as String?,
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      createDate: DateTime.fromMillisecondsSinceEpoch(
        create == 0 ? DateTime.now().millisecondsSinceEpoch : create,
      ),
      modifiedDate: DateTime.fromMillisecondsSinceEpoch(
        modified == 0 ? DateTime.now().millisecondsSinceEpoch : modified,
      ),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      category: AppCategory.parse(map['category'] as String?),
      primaryLabel: map['primary_label'] as String?,
      subcategory: map['subcategory'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      labelsJson: map['labels_json'] as String?,
      analyzedAt: analyzed == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(analyzed),
      organizedAt: organized == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(organized),
      cameraMake: map['camera_make'] as String?,
      cameraModel: map['camera_model'] as String?,
      analysisVersion: (map['analysis_version'] as num?)?.toInt() ?? 0,
    );
  }
}
