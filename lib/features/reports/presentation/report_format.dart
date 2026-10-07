abstract final class ReportFormat {
  static const int _basisPoints = 10000;
  static const int _basisPointsPerPercent = 100;
  static const int _basisPointsPerTenthPercent = 10;

  /// "34.8%" for [part] out of [whole], using integer maths only.
  static String percent(int part, int whole) {
    if (whole <= 0) return '0.0%';
    final basisPoints = part * _basisPoints ~/ whole;
    final abs = basisPoints.abs();
    final sign = basisPoints < 0 ? '-' : '';
    return '$sign${abs ~/ _basisPointsPerPercent}.${(abs % _basisPointsPerPercent) ~/ _basisPointsPerTenthPercent}%';
  }

  /// "2026-10-06", the format spreadsheets sort and parse reliably.
  static String isoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
