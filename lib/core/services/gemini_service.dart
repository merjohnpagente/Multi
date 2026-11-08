import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../shared/models/ai_models.dart';
import '../../shared/models/app_category.dart';
import '../utilities/slug_utils.dart';

class GeminiException implements Exception {
  GeminiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isRateLimited => statusCode == 429;
  bool get isAuthError => statusCode == 400 || statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Online photo identification using the Gemini API (user supplies the key).
class GeminiService {
  GeminiService();

  static const List<String> _models = <String>[
    'gemini-flash-latest',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ];

  static const String _prompt =
      'You are the image classifier of a photo organizer app. Look at the '
      'photo and identify its MAIN subject as accurately as possible. '
      'Reply with JSON only, using exactly these keys: '
      '"label" (short specific name of the main subject, e.g. "Golden retriever", '
      '"Pizza", "Sunflower", "Motorcycle"), '
      '"category" (one of: animals, nature, places, food, vehicles, people, '
      'plants, documents, other), '
      '"subcategory" (short Title Case group inside the category; for animals '
      'prefer one of Dogs, Cats, Birds, Horses, Farm animals, Wild animals, '
      'Fish, Insects, Reptiles & Amphibians, Marine life; for other categories '
      'use a sensible short group such as Landscapes, Beaches, Buildings, '
      'Drinks, Cars, Portraits, Flowers, Screenshots), '
      '"confidence" (number from 0 to 1), '
      '"description" (one short sentence). '
      'Use "people" only when a person is the main subject, "plants" for '
      'flowers, trees and leaves, "documents" for text, papers and screenshots, '
      'and "other" only if nothing else fits.';

  /// Throws [GeminiException] when the request fails.
  Future<AiIdentification> classify(
    Uint8List bytes, {
    required String apiKey,
    String extension = 'jpg',
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Uint8List jpeg = await compute(_prepareJpeg, bytes);
    final String body = jsonEncode(<String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'inline_data': <String, String>{
                'mime_type': 'image/jpeg',
                'data': base64Encode(jpeg),
              },
            },
            <String, dynamic>{'text': _prompt},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
    });

    GeminiException? lastError;
    for (final String model in _models) {
      try {
        final String text = await _generate(model, apiKey, body);
        final AiIdentification result =
            _parse(text, extension, stopwatch.elapsedMilliseconds);
        return result;
      } on GeminiException catch (error) {
        lastError = error;
        // Model name not available: try the next one. Anything else: stop.
        if (error.statusCode != 404) {
          rethrow;
        }
      }
    }
    throw lastError ?? GeminiException('Gemini request failed.');
  }

  Future<String> _generate(String model, String apiKey, String body) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final Uri uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent',
      );
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('x-goog-api-key', apiKey);
      request.add(utf8.encode(body));
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 40));
      final String raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        String message = 'Gemini error ${response.statusCode}';
        try {
          final dynamic decoded = jsonDecode(raw);
          final dynamic error = decoded is Map ? decoded['error'] : null;
          if (error is Map && error['message'] is String) {
            message = '$message: ${error['message']}';
          }
        } catch (_) {}
        throw GeminiException(message, statusCode: response.statusCode);
      }
      final dynamic decoded = jsonDecode(raw);
      final dynamic candidates = decoded is Map ? decoded['candidates'] : null;
      if (candidates is List && candidates.isNotEmpty) {
        final dynamic content = (candidates.first as Map)['content'];
        final dynamic parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          final StringBuffer buffer = StringBuffer();
          for (final dynamic part in parts) {
            if (part is Map && part['text'] is String) {
              buffer.write(part['text'] as String);
            }
          }
          if (buffer.isNotEmpty) {
            return buffer.toString();
          }
        }
      }
      throw GeminiException('Gemini returned no answer for this photo.');
    } on TimeoutException {
      throw GeminiException('Gemini took too long to answer.');
    } on SocketException {
      throw GeminiException('No internet connection.');
    } on HandshakeException {
      throw GeminiException('Secure connection to Gemini failed.');
    } finally {
      client.close(force: true);
    }
  }

  AiIdentification _parse(String text, String extension, int elapsedMs) {
    String cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```[a-zA-Z]*'), '')
          .replaceAll('```', '')
          .trim();
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      throw GeminiException('Gemini answer could not be read.');
    }
    final Map<dynamic, dynamic>? map = decoded is Map
        ? decoded
        : (decoded is List && decoded.isNotEmpty && decoded.first is Map
            ? decoded.first as Map<dynamic, dynamic>
            : null);
    if (map == null) {
      throw GeminiException('Gemini answer could not be read.');
    }

    final String label = _clean(map['label']) ?? 'Photo';
    final String categoryName =
        (_clean(map['category']) ?? 'other').toLowerCase();
    final AppCategory category = AppCategory.values.firstWhere(
      (AppCategory value) => value.name == categoryName,
      orElse: () => AppCategory.other,
    );
    final String subcategory = _clean(map['subcategory']) ?? 'General';
    final double confidence =
        ((map['confidence'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0).toDouble();
    final String sentence = _clean(map['description']) ?? '';

    final StringBuffer buffer = StringBuffer()
      ..write('Online AI (Gemini) identified "$label" ')
      ..write('(${category.label} · $subcategory). ');
    if (sentence.isNotEmpty) {
      buffer.write('$sentence ');
    }
    buffer.write('This photo was sent to Google Gemini for analysis.');
    final String description = buffer.toString();

    return AiIdentification(
      primaryLabel: label,
      category: category,
      subcategory: subcategory,
      confidence: confidence,
      description: description,
      suggestedFilename: suggestedFilename(label, extension),
      labels: <LabelScore>[
        LabelScore(label: label, confidence: confidence, source: 'gemini'),
      ],
      uncertain: confidence < 0.4,
      inferenceMs: elapsedMs,
    );
  }

  static String? _clean(dynamic value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Shrinks the photo so the upload is small and quick.
Uint8List _prepareJpeg(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }
  const int maxSide = 1024;
  img.Image resized = decoded;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxSide)
        : img.copyResize(decoded, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
