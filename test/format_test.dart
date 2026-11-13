import 'package:amar_hisab/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const en = Fmt(true);
  const bn = Fmt(false);

  test('lakh/crore grouping', () {
    expect(groupLakh('999'), '999');
    expect(groupLakh('1000'), '1,000');
    expect(groupLakh('100000'), '1,00,000');
    expect(groupLakh('1234567'), '12,34,567');
    expect(groupLakh('123456789'), '12,34,56,789');
  });

  test('money in English and Bengali digits', () {
    expect(en.money(1234567), '৳12,34,567');
    expect(bn.money(1234567), '৳১২,৩৪,৫৬৭');
    expect(en.money(1234.5), '৳1,234.5');
    expect(en.money(10.25), '৳10.25');
    expect(en.money(0), '৳0');
    expect(en.money(-50), '−৳50');
  });

  test('Bengali digits are normalised for parsing', () {
    expect(normalizeDigits('১২.৫০'), '12.50');
    expect(double.parse(normalizeDigits('১২৩')), 123);
  });

  test('date helpers', () {
    expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
    expect(en.dateLabel('2026-03-05'), '05 Mar 2026');
    expect(bn.dateLabel('2026-03-05'), '০৫ মার্চ ২০২৬');
    expect(en.dateLabel('garbage'), 'garbage');
  });
}
