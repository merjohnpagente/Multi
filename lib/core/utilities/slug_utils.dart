import 'formatters.dart';

String slugify(String input) {
  final String cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (cleaned.isEmpty) {
    return 'photo';
  }
  return cleaned.length > 48 ? cleaned.substring(0, 48) : cleaned;
}

String humanizeLabel(String input) {
  String value = input.split(',').first.trim();
  value = value.replaceAll('_', ' ');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isEmpty) {
    return 'Unknown object';
  }
  return value
      .split(' ')
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        if (word.toLowerCase() == 'and') {
          return 'and';
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String suggestedFilename(
  String label,
  String extension, {
  DateTime? now,
}) {
  final DateTime time = now ?? DateTime.now();
  final String slug = slugify(label);
  final String stamp = '${time.year}${twoDigits(time.month)}'
      '${twoDigits(time.day)}_${twoDigits(time.hour)}${twoDigits(time.minute)}';
  final String cleanExtension = extension.toLowerCase().replaceAll('.', '');
  return '${slug}_$stamp.${cleanExtension.isEmpty ? 'jpg' : cleanExtension}';
}
