abstract final class AppDates {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "12 Nov 2026"
  static String short(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Mon"
  static String weekdayShort(DateTime date) => _weekdays[date.weekday - 1];
}
