import 'dart:convert';

import 'db.dart';
import 'l10n.dart';

class BackupData {
  final List<Account> accounts;
  final List<Txn> txns;
  const BackupData(this.accounts, this.txns);
}

String encodeBackup(List<Account> accounts, List<Txn> txns, {DateTime? now}) =>
    jsonEncode({
      'app': 'amar_hisab',
      'version': 2,
      'exported_at': (now ?? DateTime.now()).toIso8601String(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'transactions': txns.map((t) => t.toMap()).toList(),
    });

int _int(Object? v, String what) {
  if (v is int) return v;
  throw FormatException('Invalid $what');
}

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses and fully validates a backup. Throws [FormatException] if anything
/// is wrong, so a bad file can never damage existing data.
BackupData decodeBackup(String text) {
  dynamic root;
  try {
    root = jsonDecode(text.trim());
  } on FormatException {
    throw const FormatException('Not valid backup text');
  }
  if (root is! Map || root['app'] != 'amar_hisab') {
    throw const FormatException('Not an Amar Hisab backup');
  }
  final accRaw = root['accounts'];
  final txRaw = root['transactions'];
  if (accRaw is! List || txRaw is! List) {
    throw const FormatException('Backup is incomplete');
  }

  final accounts = <Account>[];
  final ids = <int>{};
  for (final a in accRaw) {
    if (a is! Map) throw const FormatException('Invalid account');
    final id = _int(a['id'], 'account id');
    final name = a['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid account name');
    }
    if (!ids.add(id)) throw const FormatException('Duplicate account');
    final kind = a['kind'];
    accounts.add(Account(
      id: id,
      name: name.trim(),
      kind: (kind is String && accountKinds.contains(kind)) ? kind : 'personal',
    ));
  }
  if (accounts.isEmpty) throw const FormatException('Backup has no accounts');

  final txns = <Txn>[];
  final txIds = <int>{};
  for (final t in txRaw) {
    if (t is! Map) throw const FormatException('Invalid transaction');
    final id = _int(t['id'], 'transaction id');
    final accountId = _int(t['account_id'], 'account reference');
    if (!txIds.add(id)) throw const FormatException('Duplicate transaction');
    if (!ids.contains(accountId)) {
      throw const FormatException('Transaction points to missing account');
    }
    final type = t['type'];
    if (type != 'income' && type != 'expense') {
      throw const FormatException('Invalid transaction type');
    }
    final amount = t['amount'];
    if (amount is! num || !amount.isFinite || amount <= 0) {
      throw const FormatException('Invalid amount');
    }
    final category = t['category'];
    if (category is! String || category.trim().isEmpty) {
      throw const FormatException('Invalid category');
    }
    final note = t['note'];
    final date = t['date'];
    if (date is! String || !_dateRe.hasMatch(date) || DateTime.tryParse(date) == null) {
      throw const FormatException('Invalid date');
    }
    txns.add(Txn(
      id: id,
      accountId: accountId,
      type: type as String,
      amount: amount.toDouble(),
      category: category,
      note: note is String ? note : '',
      date: date,
    ));
  }
  return BackupData(accounts, txns);
}
