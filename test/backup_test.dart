import 'dart:convert';

import 'package:amar_hisab/backup.dart';
import 'package:amar_hisab/db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accounts = [
    Account(id: 1, name: 'ব্যক্তিগত', kind: 'personal'),
    Account(id: 2, name: 'Shop', kind: 'business'),
  ];
  const txns = [
    Txn(id: 1, accountId: 1, type: 'income', amount: 5000.5, category: 'salary', note: '', date: '2026-11-01'),
    Txn(id: 2, accountId: 2, type: 'expense', amount: 120, category: 'food', note: 'চা', date: '2026-11-02'),
  ];

  test('round trip keeps everything', () {
    final text = encodeBackup(accounts, txns);
    final back = decodeBackup(text);
    expect(back.accounts.length, 2);
    expect(back.accounts[1].kind, 'business');
    expect(back.txns.length, 2);
    expect(back.txns[0].amount, 5000.5);
    expect(back.txns[1].note, 'চা');
  });

  test('garbage and foreign JSON are rejected', () {
    expect(() => decodeBackup('hello'), throwsFormatException);
    expect(() => decodeBackup('{"a":1}'), throwsFormatException);
    expect(() => decodeBackup('[]'), throwsFormatException);
  });

  Map<String, Object?> base() =>
      jsonDecode(encodeBackup(accounts, txns)) as Map<String, Object?>;

  test('bad amounts, dates, types and references are rejected', () {
    final b1 = base();
    ((b1['transactions'] as List)[0] as Map)['amount'] = -5;
    expect(() => decodeBackup(jsonEncode(b1)), throwsFormatException);

    final b2 = base();
    ((b2['transactions'] as List)[0] as Map)['date'] = '01/11/2026';
    expect(() => decodeBackup(jsonEncode(b2)), throwsFormatException);

    final b3 = base();
    ((b3['transactions'] as List)[0] as Map)['type'] = 'loan';
    expect(() => decodeBackup(jsonEncode(b3)), throwsFormatException);

    final b4 = base();
    ((b4['transactions'] as List)[0] as Map)['account_id'] = 99;
    expect(() => decodeBackup(jsonEncode(b4)), throwsFormatException);
  });
}
