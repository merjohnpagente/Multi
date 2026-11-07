import 'package:flutter_test/flutter_test.dart';
import 'package:j_pix/core/services/duplicate_service.dart';

DuplicateGroup _group(String kind, List<String> ids, int totalSize) {
  return DuplicateGroup(
    kind: kind,
    signature: 'sig-$kind',
    assetIds: ids,
    totalSize: totalSize,
  );
}

void main() {
  group('Test 3 - find duplicate photos', () {
    test('counts photos in a group', () {
      final DuplicateGroup group = _group('exact', <String>['a', 'b', 'c'], 3000);
      expect(group.photoCount, 3);
    });

    test('estimates space saved by keeping one copy', () {
      final DuplicateGroup group = _group('exact', <String>['a', 'b', 'c'], 3000);
      expect(group.potentialSavings, 2000);
    });

    test('an empty group saves nothing', () {
      expect(_group('exact', <String>[], 0).potentialSavings, 0);
    });

    test('scan result totals exact and similar groups', () {
      final DuplicateScanResult result = DuplicateScanResult(
        scanId: 'scan-1',
        exact: <DuplicateGroup>[
          _group('exact', <String>['a', 'b'], 2000),
        ],
        similar: <DuplicateGroup>[
          _group('similar', <String>['c', 'd', 'e'], 3000),
        ],
        scanned: 50,
        skipped: 1,
      );
      expect(result.groupCount, 2);
      expect(result.duplicatePhotoCount, 5);
    });

    test('scan with no duplicates is empty', () {
      const DuplicateScanResult result = DuplicateScanResult(
        scanId: 'scan-2',
        exact: <DuplicateGroup>[],
        similar: <DuplicateGroup>[],
        scanned: 10,
        skipped: 0,
      );
      expect(result.groupCount, 0);
      expect(result.duplicatePhotoCount, 0);
    });
  });
}
