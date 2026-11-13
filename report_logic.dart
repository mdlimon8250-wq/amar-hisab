import 'format.dart';

enum Period { daily, weekly, monthly }

/// Inclusive date range (date-only values).
class DateRange {
  final DateTime from;
  final DateTime to;
  const DateRange(this.from, this.to);

  String get fromKey => dateKey(from);
  String get toKey => dateKey(to);

  List<DateTime> get days {
    final out = <DateTime>[];
    for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      out.add(d);
    }
    return out;
  }
}

/// Range containing [anchor]. Weeks start on Saturday (Bangladesh).
DateRange rangeFor(Period p, DateTime anchor) {
  final a = dateOnly(anchor);
  switch (p) {
    case Period.daily:
      return DateRange(a, a);
    case Period.weekly:
      final back = (a.weekday - DateTime.saturday + 7) % 7;
      final start = DateTime(a.year, a.month, a.day - back);
      return DateRange(start, DateTime(start.year, start.month, start.day + 6));
    case Period.monthly:
      return DateRange(DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 0));
  }
}

DateTime shiftAnchor(Period p, DateTime anchor, int delta) {
  switch (p) {
    case Period.daily:
      return DateTime(anchor.year, anchor.month, anchor.day + delta);
    case Period.weekly:
      return DateTime(anchor.year, anchor.month, anchor.day + 7 * delta);
    case Period.monthly:
      return DateTime(anchor.year, anchor.month + delta, 1);
  }
}
