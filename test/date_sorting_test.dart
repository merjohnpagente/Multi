import 'package:flutter_test/flutter_test.dart';
import 'package:j_pix/core/utilities/formatters.dart';

void main() {
  group('Test 1 - sort photos by date (metadata)', () {
    test('groups a photo under its month and year heading', () {
      expect(formatMonthYear(DateTime(2026, 11, 7)), 'November 2026');
      expect(formatMonthYear(DateTime(2025, 1, 31)), 'January 2025');
    });

    test('formats the date taken', () {
      expect(formatDate(DateTime(2026, 11, 7)), 'Nov 7, 2026');
      expect(formatDate(null), 'Not available');
    });

    test('builds a sortable date key', () {
      expect(formatDateKey(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('formats time in 12-hour clock', () {
      expect(formatTime(DateTime(2026, 11, 7, 18, 5)), '6:05 PM');
      expect(formatTime(DateTime(2026, 11, 7, 0, 0)), '12:00 AM');
      expect(formatTime(DateTime(2026, 11, 7, 12, 30)), '12:30 PM');
    });
  });
}
