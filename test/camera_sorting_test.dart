import 'package:flutter_test/flutter_test.dart';
import 'package:j_pix/shared/models/photo_metadata.dart';

PhotoMetadata _meta({String? make, String? model, double? lat, double? lng}) {
  return PhotoMetadata(
    title: 'IMG_0001.jpg',
    fileSize: 1024,
    width: 4000,
    height: 3000,
    format: 'JPG',
    takenAt: DateTime(2026, 11, 7),
    cameraMake: make,
    cameraModel: model,
    latitude: lat,
    longitude: lng,
    exif: const <String, dynamic>{},
  );
}

void main() {
  group('Test 2 - sort photos by camera (metadata)', () {
    test('combines camera make and model', () {
      expect(
        _meta(make: 'Samsung', model: 'Galaxy S23').cameraLabel,
        'Samsung Galaxy S23',
      );
    });

    test('returns null when there is no camera data', () {
      expect(_meta().cameraLabel, isNull);
      expect(_meta(make: '  ', model: '').cameraLabel, isNull);
    });

    test('uses only the model when make is missing', () {
      expect(_meta(model: 'Pixel 8').cameraLabel, 'Pixel 8');
    });

    test('cleans extra spaces', () {
      expect(
        _meta(make: ' Canon ', model: 'EOS  R5').cameraLabel,
        'Canon EOS R5',
      );
    });

    test('shows resolution and location labels', () {
      final PhotoMetadata photo = _meta(lat: 8.0667, lng: 123.75);
      expect(photo.resolutionLabel, '4000 × 3000');
      expect(photo.locationLabel, '8.06670, 123.75000');
      expect(_meta().locationLabel, 'Not available');
    });
  });
}
