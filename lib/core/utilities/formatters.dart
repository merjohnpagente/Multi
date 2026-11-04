const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatCount(int value) {
  if (value < 1000) {
    return '$value';
  }
  if (value < 1000000) {
    final double thousands = value / 1000;
    return '${_trimDecimal(thousands)}K';
  }
  final double millions = value / 1000000;
  return '${_trimDecimal(millions)}M';
}

String _trimDecimal(double value) {
  final String text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String formatFileSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  int unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final String value = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$value ${units[unit]}';
}

String formatStorageGB(int bytes) {
  if (bytes <= 0) {
    return '0 GB';
  }
  final double gb = bytes / (1024 * 1024 * 1024);
  if (gb < 1) {
    return formatFileSize(bytes);
  }
  return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} GB';
}

String formatDate(DateTime? date) {
  if (date == null) {
    return 'Not available';
  }
  return '${_shortMonths[date.month - 1]} ${date.day}, ${date.year}';
}

String formatDateTime(DateTime? date) {
  if (date == null) {
    return 'Not available';
  }
  return '${formatDate(date)} · ${formatTime(date)}';
}

String formatTime(DateTime date) {
  final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final String suffix = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:${twoDigits(date.minute)} $suffix';
}

String formatDayHeader(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime target = DateTime(date.year, date.month, date.day);
  final int difference = today.difference(target).inDays;
  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }
  if (difference > 1 && difference < 7) {
    return _weekdays[date.weekday - 1];
  }
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatRelative(DateTime? date) {
  if (date == null) {
    return 'Never';
  }
  final Duration diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    final int minutes = diff.inMinutes;
    return '$minutes min ago';
  }
  if (diff.inHours < 24) {
    final int hours = diff.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    final int days = diff.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  return formatDate(date);
}

String formatMonthYear(DateTime date) =>
    '${_months[date.month - 1]} ${date.year}';

String formatDateKey(DateTime date) =>
    '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';

String formatCoordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return 'Not available';
  }
  final String latDirection = latitude >= 0 ? 'N' : 'S';
  final String lngDirection = longitude >= 0 ? 'E' : 'W';
  return '${latitude.abs().toStringAsFixed(5)}° $latDirection, '
      '${longitude.abs().toStringAsFixed(5)}° $lngDirection';
}

String formatPercent(double value) => '${(value * 100).round()}%';

String normalizedExtension(String title, String? mimeType) {
  final int dot = title.lastIndexOf('.');
  if (dot >= 0 && dot < title.length - 1) {
    final String extension = title.substring(dot + 1).toLowerCase();
    if (extension.length <= 5) {
      return extension;
    }
  }
  if (mimeType != null) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
      case 'image/heif':
        return 'heic';
      case 'image/gif':
        return 'gif';
    }
  }
  return 'jpg';
}
