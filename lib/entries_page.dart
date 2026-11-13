import 'package:flutter/material.dart';

import 'app_state.dart';
import 'db.dart';
import 'l10n.dart';
import 'txn_form.dart';
import 'widgets.dart';

class EntriesPage extends StatefulWidget {
  final AppState state;
  const EntriesPage({super.key, required this.state});
  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  late final Listenable _listenable;
  int _seq = 0;
  bool _loading = true;
  String? _error;
  List<Txn> _all = [];
  String _query = '';
  String? _type; // null = all

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _listenable = Listenable.merge([s, s.rev]);
    _listenable.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _listenable.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final seq = ++_seq;
    try {
      final rows = await HisabDb.instance.transactions(accountId: s.accountId);
      if (!mounted || seq != _seq) return;
      setState(() {
        _all = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  List<Txn> get _filtered {
    final q = _query.toLowerCase();
    return _all.where((x) {
      if (_type != null && x.type != _type) return false;
      if (q.isEmpty) return true;
      return categoryLabel(x.category, s.english).toLowerCase().contains(q) ||
          x.note.toLowerCase().contains(q) ||
          x.amount.toString().contains(q);
    }).toList();
  }

  Future<void> _delete(Txn x) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _all = _all.where((e) => e.id != x.id).toList());
    await HisabDb.instance.deleteTxn(x.id!);
    s.bump();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.t('লেনদেন মুছে ফেলা হয়েছে', 'Entry deleted')),
        action: SnackBarAction(
          label: s.t('ফিরিয়ে আনুন', 'Undo'),
          onPressed: () async {
            await HisabDb.instance.restoreTxn(x);
            s.bump();
          },
        ),
      ));
  }

  Future<void> _confirmDelete(Txn x) async {
    final yes = await confirmDialog(
      context,
      title: s.t('লেনদেন মুছবেন?', 'Delete entry?'),
      body: s.t('এই কাজটি আর ফেরানো যাবে না।', 'This cannot be undone.'),
      ok: s.t('মুছুন', 'Delete'),
      cancel: s.t('না', 'Cancel'),
    );
    if (yes && x.id != null) await _delete(x);
  }

  Widget _swipeBg(BuildContext context, Alignment a) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: a,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final f = s.fmt;
    final items = _filtered;

    // flat list: date header (String) followed by that day's transactions
    final rows = <Object>[];
    final dayNet = <String, double>{};
    for (final x in items) {
      dayNet[x.date] = (dayNet[x.date] ?? 0) + (x.type == 'income' ? x.amount : -x.amount);
    }
    String? last;
    for (final x in items) {
      if (x.date != last) {
        rows.add(x.date);
        last = x.date;
      }
      rows.add(x);
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: s.t('খুঁজুন…', 'Search…'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final e in <MapEntry<String?, String>>[
            MapEntry(null, s.t('সব', 'All')),
            MapEntry('income', s.t('আয়', 'Income')),
            MapEntry('expense', s.t('ব্যয়', 'Expense')),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: _type == e.key,
                onSelected: (_) => setState(() => _type = e.key),
              ),
            ),
        ]),
      ),
      Expanded(
        child: items.isEmpty
            ? EmptyState(s)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  if (r is String) {
                    final net = dayNet[r] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 14, 6, 2),
                      child: Row(children: [
                        Expanded(
                          child: Text(f.dateLabel(r),
                              style: Theme.of(context).textTheme.labelLarge),
                        ),
                        Text(f.money(net),
                            style: TextStyle(
                                fontSize: 12,
                                color: net >= 0
                                    ? incomeColor(context)
                                    : expenseColor(context))),
                      ]),
                    );
                  }
                  final x = r as Txn;
                  return Dismissible(
                    key: ValueKey('txn_${x.id}'),
                    background: _swipeBg(context, Alignment.centerLeft),
                    secondaryBackground: _swipeBg(context, Alignment.centerRight),
                    onDismissed: (_) => _delete(x),
                    child: TxnTile(
                      txn: x,
                      state: s,
                      showAccount: s.accountId == null,
                      onTap: () => openTxnForm(context, s, x),
                      onLongPress: () => _confirmDelete(x),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
