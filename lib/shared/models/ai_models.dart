import 'dart:convert';

import 'app_category.dart';

class LabelScore {
  const LabelScore({
    required this.label,
    required this.confidence,
    this.source = 'general',
  });

  final String label;
  final double confidence;
  final String source;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'label': label,
        'confidence': confidence,
        'source': source,
      };

  factory LabelScore.fromMap(Map<String, dynamic> map) => LabelScore(
        label: map['label'] as String? ?? '',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
        source: map['source'] as String? ?? 'general',
      );

  static List<LabelScore> fromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <LabelScore>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LabelScore>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LabelScore.fromMap)
          .toList(growable: false);
    } catch (_) {
      return const <LabelScore>[];
    }
  }

  static String toJson(List<LabelScore> labels) => jsonEncode(
        labels.map((LabelScore label) => label.toMap()).toList(),
      );
}

class AiIdentification {
  const AiIdentification({
    required this.primaryLabel,
    required this.category,
    required this.subcategory,
    required this.confidence,
    required this.description,
    required this.suggestedFilename,
    required this.labels,
    required this.uncertain,
    required this.inferenceMs,
  });

  final String primaryLabel;
  final AppCategory category;
  final String subcategory;
  final double confidence;
  final String description;
  final String suggestedFilename;
  final List<LabelScore> labels;
  final bool uncertain;
  final int inferenceMs;

  String get confidencePercent => '${(confidence * 100).round()}%';

  AiIdentification copyWith({
    String? primaryLabel,
    AppCategory? category,
    String? subcategory,
    double? confidence,
    String? description,
    String? suggestedFilename,
    List<LabelScore>? labels,
    bool? uncertain,
    int? inferenceMs,
  }) {
    return AiIdentification(
      primaryLabel: primaryLabel ?? this.primaryLabel,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      confidence: confidence ?? this.confidence,
      description: description ?? this.description,
      suggestedFilename: suggestedFilename ?? this.suggestedFilename,
      labels: labels ?? this.labels,
      uncertain: uncertain ?? this.uncertain,
      inferenceMs: inferenceMs ?? this.inferenceMs,
    );
  }
}

class AiResultRecord {
  const AiResultRecord({
    required this.key,
    required this.assetId,
    required this.filePath,
    required this.primaryLabel,
    required this.category,
    required this.subcategory,
    required this.confidence,
    required this.description,
    required this.suggestedFilename,
    required this.labels,
    required this.createdAt,
  });

  final String key;
  final String? assetId;
  final String? filePath;
  final String primaryLabel;
  final AppCategory category;
  final String subcategory;
  final double confidence;
  final String description;
  final String suggestedFilename;
  final List<LabelScore> labels;
  final DateTime createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'key': key,
        'asset_id': assetId,
        'file_path': filePath,
        'primary_label': primaryLabel,
        'category': category.name,
        'subcategory': subcategory,
        'confidence': confidence,
        'description': description,
        'suggested_filename': suggestedFilename,
        'labels_json': LabelScore.toJson(labels),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AiResultRecord.fromMap(Map<String, Object?> map) => AiResultRecord(
        key: map['key'] as String? ?? '',
        assetId: map['asset_id'] as String?,
        filePath: map['file_path'] as String?,
        primaryLabel: map['primary_label'] as String? ?? 'Unknown',
        category: AppCategory.parse(map['category'] as String?),
        subcategory: map['subcategory'] as String? ?? 'Other',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
        description: map['description'] as String? ?? '',
        suggestedFilename: map['suggested_filename'] as String? ?? '',
        labels: LabelScore.fromJson(map['labels_json'] as String?),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
}
