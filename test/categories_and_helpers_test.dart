import 'package:flutter_test/flutter_test.dart';
import 'package:j_pix/core/utilities/formatters.dart';
import 'package:j_pix/core/utilities/label_taxonomy.dart';
import 'package:j_pix/core/utilities/slug_utils.dart';
import 'package:j_pix/shared/models/app_category.dart';

void main() {
  group('Test 4 - categories and helpers', () {
    test('parses a saved category name', () {
      expect(AppCategory.parse('food'), AppCategory.food);
      expect(AppCategory.parse('animals'), AppCategory.animals);
    });

    test('unknown or empty category becomes Other', () {
      expect(AppCategory.parse('nonsense'), AppCategory.other);
      expect(AppCategory.parse(null), AppCategory.other);
      expect(AppCategory.parse(''), AppCategory.other);
    });

    test('plant model labels go to the Plants category', () {
      final LabelInfo info =
          LabelTaxonomy.describe('rose', source: 'plant');
      expect(info.category, AppCategory.plants);
    });

    test('bird model labels go to the Animals category', () {
      final LabelInfo info =
          LabelTaxonomy.describe('house sparrow', source: 'bird');
      expect(info.category, AppCategory.animals);
      expect(info.subcategory, 'Birds');
    });

    test('formats file sizes', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1536), '1.5 KB');
    });

    test('builds a clean suggested filename', () {
      expect(
        suggestedFilename(
          'Golden Retriever',
          'JPG',
          now: DateTime(2026, 11, 7, 18, 5),
        ),
        'golden_retriever_20261107_1805.jpg',
      );
    });

    test('humanizes labels', () {
      expect(humanizeLabel('golden_retriever, dog'), 'Golden Retriever');
      expect(humanizeLabel(''), 'Unknown object');
    });
  });
}
