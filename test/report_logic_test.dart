import 'package:amar_hisab/report_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily range is a single day', () {
    final r = rangeFor(Period.daily, DateTime(2026, 11, 12, 18, 30));
    expect(r.fromKey, '2026-11-12');
    expect(r.toKey, '2026-11-12');
    expect(r.days.length, 1);
  });

  test('week runs Saturday to Friday', () {
    // 2026-11-11 is a Wednesday
    final r = rangeFor(Period.weekly, DateTime(2026, 11, 11));
    expect(r.fromKey, '2026-11-07');
    expect(r.toKey, '2026-11-13');
    expect(r.days.length, 7);
    // a Saturday starts its own week, a Friday ends it
    expect(rangeFor(Period.weekly, DateTime(2026, 11, 7)).fromKey, '2026-11-07');
    expect(rangeFor(Period.weekly, DateTime(2026, 11, 13)).fromKey, '2026-11-07');
  });

  test('month range handles leap years and year ends', () {
    expect(rangeFor(Period.monthly, DateTime(2028, 2, 10)).toKey, '2028-02-29');
    expect(rangeFor(Period.monthly, DateTime(2027, 2, 10)).toKey, '2027-02-28');
    final dec = rangeFor(Period.monthly, DateTime(2026, 12, 31));
    expect(dec.fromKey, '2026-12-01');
    expect(dec.toKey, '2026-12-31');
    expect(dec.days.length, 31);
  });

  test('shiftAnchor moves by the right unit', () {
    expect(shiftAnchor(Period.daily, DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    expect(shiftAnchor(Period.weekly, DateTime(2026, 1, 1), 1), DateTime(2026, 1, 8));
    expect(shiftAnchor(Period.monthly, DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    expect(shiftAnchor(Period.monthly, DateTime(2026, 1, 15), -1), DateTime(2025, 12, 1));
  });
}
