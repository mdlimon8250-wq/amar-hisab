// Formatting helpers: Bangladeshi digit/lakh grouping, dates, BDT money.
// Implemented by hand (no intl) so no locale data has to be loaded.

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
const _bnMonths = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];
const _enMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _bnWeek = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
const _enWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 'yyyy-MM-dd' key used for storage and range queries.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String s) => DateTime.tryParse(s);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Converts Bengali digits to ASCII digits (for parsing typed amounts).
String normalizeDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x09E6 && r <= 0x09EF) {
      b.writeCharCode(0x30 + (r - 0x09E6));
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// Groups digits the Bangladeshi way: 12,34,567.
String groupLakh(String intPart) {
  if (intPart.length <= 3) return intPart;
  final last3 = intPart.substring(intPart.length - 3);
  var rest = intPart.substring(0, intPart.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

class Fmt {
  final bool en;
  const Fmt(this.en);

  /// Replaces ASCII digits with Bengali digits when the UI is Bengali.
  String digits(String s) {
    if (en) return s;
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x30 && r <= 0x39) {
        b.write(_bnDigits[r - 0x30]);
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  String number(num n) {
    final cents = (n.abs() * 100).round();
    final whole = cents ~/ 100;
    final frac = cents % 100;
    var s = groupLakh(whole.toString());
    if (frac != 0) {
      final f = frac.toString().padLeft(2, '0');
      s = '$s.${f.endsWith('0') ? f.substring(0, 1) : f}';
    }
    return digits(s);
  }

  String money(num n) {
    final neg = n < 0 && (n.abs() * 100).round() != 0;
    return '${neg ? '−' : ''}৳${number(n)}';
  }

  String monthName(int month) => en ? _enMonths[month - 1] : _bnMonths[month - 1];

  String day(DateTime d) =>
      digits('${d.day.toString().padLeft(2, '0')} ${monthName(d.month)} ${d.year}');

  String dayMonth(DateTime d) => digits('${d.day} ${monthName(d.month)}');

  String monthYear(DateTime d) => digits('${monthName(d.month)} ${d.year}');

  String weekdayShort(DateTime d) => en ? _enWeek[d.weekday - 1] : _bnWeek[d.weekday - 1];

  String dateLabel(String key) {
    final d = parseDateKey(key);
    return d == null ? key : day(d);
  }
}
