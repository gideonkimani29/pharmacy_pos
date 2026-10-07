import 'package:equatable/equatable.dart';

/// An inclusive range of calendar days. Times are ignored.
class ReportRange extends Equatable {
  ReportRange({required DateTime from, required DateTime to})
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);

  final DateTime from;
  final DateTime to;

  int get dayCount => DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays +
      1;

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  /// The [index]th day of the range, counting from 0.
  DateTime dayAt(int index) => DateTime(from.year, from.month, from.day + index);

  @override
  List<Object?> get props => [from, to];
}
