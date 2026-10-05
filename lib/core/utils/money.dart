import '../constants/app_config.dart';

/// Money is always integer minor units (cents). No floating point anywhere.
abstract final class Money {
  static const int _groupSize = 3;
  static const int _fractionDigits = 2;

  /// "KES 1,234.50"
  static String format(int minor) => '${AppConfig.currencyCode} ${formatPlain(minor, grouped: true)}';

  /// "1234.50", or "1,234.50" when [grouped].
  static String formatPlain(int minor, {bool grouped = false}) {
    final negative = minor < 0;
    final abs = minor.abs();
    final whole = abs ~/ AppConfig.minorUnitsPerMajor;
    final fraction = (abs % AppConfig.minorUnitsPerMajor).toString().padLeft(_fractionDigits, '0');
    final wholeText = grouped ? _group(whole) : whole.toString();
    return '${negative ? '-' : ''}$wholeText.$fraction';
  }

  /// Parses "1234", "1,234.5" or "1234.50" into minor units. Returns null if invalid.
  static int? parseMinor(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(_fractionDigits, '0');
    return whole * AppConfig.minorUnitsPerMajor + int.parse(fraction);
  }

  static String _group(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % _groupSize == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
