import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'l10n.dart';

class Account {
  final int id;
  final String name;
  final String kind; // personal | family | business
  const Account({required this.id, required this.name, required this.kind});

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int,
        name: m['name'] as String,
        kind: (m['kind'] as String?) ?? 'personal',
      );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'kind': kind};
}

class Txn {
  final int? id;
  final int accountId;
  final String type; // income | expense
  final double amount;
  final String category; // category key (see l10n.dart)
  final String note;
  final String date; // yyyy-MM-dd
  const Txn({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'type': type,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int,
        accountId: m['account_id'] as int,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        note: m['note'] as String,
        date: m['date'] as String,
      );
}

class Totals {
  final double income;
  final double expense;
  const Totals(this.income, this.expense);
  static const zero = Totals(0, 0);
  double get net => income - expense;
}

class CatTotal {
  final String category;
  final double amount;
  const CatTotal(this.category, this.amount);
}

class _Where {
  final String clause;
  final List<Object?> args;
  const _Where(this.clause, this.args);
}

_Where _where({int? accountId, String? type, String? from, String? to}) {
  final c = <String>[];
  final a = <Object?>[];
  if (accountId != null) {
    c.add('account_id=?');
    a.add(accountId);
  }
  if (type != null) {
    c.add('type=?');
    a.add(type);
  }
  if (from != null) {
    c.add('date>=?');
    a.add(from);
  }
  if (to != null) {
    c.add('date<=?');
    a.add(to);
  }
  return _Where(c.isEmpty ? '' : 'WHERE ${c.join(' AND ')}', a);
}

class HisabDb {
  HisabDb._();
  static final HisabDb instance = HisabDb._();

  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
      p.join(base, 'amar_hisab.db'),
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'personal',
          created_at TEXT NOT NULL)''');
        await db.execute('''CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('income','expense')),
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          date TEXT NOT NULL,
          FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE)''');
        await db.execute(
            'CREATE INDEX idx_txn_account_date ON transactions(account_id, date)');
        await db.execute('CREATE INDEX idx_txn_type ON transactions(type)');
        await db.execute('CREATE INDEX idx_txn_date ON transactions(date)');
        final now = DateTime.now().toIso8601String();
        await db.insert('accounts', {'name': 'ব্যক্তিগত', 'kind': 'personal', 'created_at': now});
        await db.insert('accounts', {'name': 'ব্যবসা', 'kind': 'business', 'created_at': now});
        await db.insert('accounts', {'name': 'পরিবার', 'kind': 'family', 'created_at': now});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE accounts ADD COLUMN kind TEXT NOT NULL DEFAULT 'personal'");
          await db.execute("UPDATE accounts SET kind='business' WHERE name='ব্যবসা'");
          await db.execute("UPDATE accounts SET kind='family' WHERE name='পরিবার'");
          // v1 stored translated labels as category; convert to language-neutral keys.
          for (final e in legacyCategoryMap.entries) {
            await db.update('transactions', {'category': e.value},
                where: 'category=?', whereArgs: [e.key]);
          }
          await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date)');
        }
      },
    );
  }

  // ---- accounts ----
  Future<List<Account>> accounts() async {
    final db = await database;
    final rows = await db.query('accounts', orderBy: 'id');
    return rows.map(Account.fromMap).toList();
  }

  Future<int> addAccount(String name, String kind) async {
    final db = await database;
    return db.insert('accounts',
        {'name': name, 'kind': kind, 'created_at': DateTime.now().toIso8601String()});
  }

  Future<void> updateAccount(int id, String name, String kind) async {
    final db = await database;
    await db.update('accounts', {'name': name, 'kind': kind},
        where: 'id=?', whereArgs: [id]);
  }

  /// Deletes the account and all of its transactions.
  Future<void> deleteAccount(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'account_id=?', whereArgs: [id]);
      await txn.delete('accounts', where: 'id=?', whereArgs: [id]);
    });
  }

  // ---- transactions ----
  Future<int> saveTxn(Txn t) async {
    final db = await database;
    if (t.id == null) return db.insert('transactions', t.toMap());
    return db.update('transactions', t.toMap(), where: 'id=?', whereArgs: [t.id]);
  }

  /// Re-inserts a deleted transaction with its original id (undo).
  Future<void> restoreTxn(Txn t) async {
    final db = await database;
    await db.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteTxn(int id) async {
    final db = await database;
    return db.delete('transactions', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Txn>> transactions({
    int? accountId,
    String? type,
    String? from,
    String? to,
    int limit = 2000,
  }) async {
    final db = await database;
    final w = _where(accountId: accountId, type: type, from: from, to: to);
    final rows = await db.rawQuery(
      'SELECT * FROM transactions ${w.clause} ORDER BY date DESC, id DESC LIMIT ?',
      [...w.args, limit],
    );
    return rows.map(Txn.fromMap).toList();
  }

  // ---- aggregates (computed in SQL, so they are exact and fast) ----
  Future<Totals> totals({int? accountId, String? from, String? to}) async {
    final db = await database;
    final w = _where(accountId: accountId, from: from, to: to);
    final rows = await db.rawQuery(
      'SELECT type, COALESCE(SUM(amount),0) AS s FROM transactions ${w.clause} GROUP BY type',
      w.args,
    );
    var inc = 0.0, exp = 0.0;
    for (final r in rows) {
      final s = (r['s'] as num).toDouble();
      if (r['type'] == 'income') {
        inc = s;
      } else {
        exp = s;
      }
    }
    return Totals(inc, exp);
  }

  Future<List<CatTotal>> categoryTotals({
    required String type,
    int? accountId,
    String? from,
    String? to,
  }) async {
    final db = await database;
    final w = _where(accountId: accountId, type: type, from: from, to: to);
    final rows = await db.rawQuery(
      'SELECT category, SUM(amount) AS s FROM transactions ${w.clause} '
      'GROUP BY category ORDER BY s DESC',
      w.args,
    );
    return rows
        .map((r) => CatTotal(r['category'] as String, (r['s'] as num).toDouble()))
        .toList();
  }

  /// date key -> totals for that day.
  Future<Map<String, Totals>> dailyTotals({
    int? accountId,
    required String from,
    required String to,
  }) async {
    final db = await database;
    final w = _where(accountId: accountId, from: from, to: to);
    final rows = await db.rawQuery(
      'SELECT date, type, SUM(amount) AS s FROM transactions ${w.clause} GROUP BY date, type',
      w.args,
    );
    final inc = <String, double>{};
    final exp = <String, double>{};
    for (final r in rows) {
      final d = r['date'] as String;
      final s = (r['s'] as num).toDouble();
      if (r['type'] == 'income') {
        inc[d] = s;
      } else {
        exp[d] = s;
      }
    }
    final keys = {...inc.keys, ...exp.keys};
    return {for (final k in keys) k: Totals(inc[k] ?? 0, exp[k] ?? 0)};
  }

  // ---- backup / restore ----
  Future<List<Txn>> allTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'id');
    return rows.map(Txn.fromMap).toList();
  }

  /// Replaces ALL data atomically. Throws (and rolls back) on any failure.
  Future<void> replaceAll(List<Account> accounts, List<Txn> txns) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final b = txn.batch();
      b.delete('transactions');
      b.delete('accounts');
      for (final a in accounts) {
        b.insert('accounts', {...a.toMap(), 'created_at': now});
      }
      for (final t in txns) {
        b.insert('transactions', t.toMap());
      }
      await b.commit(noResult: true);
    });
  }
}
