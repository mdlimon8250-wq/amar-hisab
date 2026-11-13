import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'db.dart';
import 'format.dart';
import 'l10n.dart';
import 'widgets.dart';

Future<void> openTxnForm(BuildContext context, AppState state, [Txn? txn]) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TxnForm(state: state, txn: txn)),
    );

class TxnForm extends StatefulWidget {
  final AppState state;
  final Txn? txn;
  const TxnForm({super.key, required this.state, this.txn});
  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _type = 'expense';
  String _category = 'food';
  late int _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  AppState get s => widget.state;

  List<String> get _categories => _type == 'income' ? incomeCategories : expenseCategories;

  @override
  void initState() {
    super.initState();
    final x = widget.txn;
    if (x != null) {
      _amount.text = x.amount.toString();
      _note.text = x.note;
      _type = x.type;
      _category = x.category;
      _accountId = x.accountId;
      _date = parseDateKey(x.date) ?? DateTime.now();
    } else {
      _accountId = s.accountId ?? (s.accounts.isNotEmpty ? s.accounts.first.id : 1);
      _category = _categories.first;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final value = double.tryParse(normalizeDigits(_amount.text.trim()));
    if (value == null || value <= 0 || value > 1e12) {
      _snack(s.t('সঠিক টাকার পরিমাণ লিখুন', 'Enter a valid amount'));
      return;
    }
    setState(() => _saving = true);
    try {
      await HisabDb.instance.saveTxn(Txn(
        id: widget.txn?.id,
        accountId: _accountId,
        type: _type,
        amount: value,
        category: _category,
        note: _note.text.trim(),
        date: dateKey(_date),
      ));
      s.bump();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(s.t('সংরক্ষণ করা যায়নি', 'Could not save'));
      }
    }
  }

  Future<void> _delete() async {
    final x = widget.txn;
    if (x == null || x.id == null) return;
    final yes = await confirmDialog(
      context,
      title: s.t('লেনদেন মুছবেন?', 'Delete entry?'),
      body: s.t('এই কাজটি আর ফেরানো যাবে না।', 'This cannot be undone.'),
      ok: s.t('মুছুন', 'Delete'),
      cancel: s.t('না', 'Cancel'),
    );
    if (!yes) return;
    await HisabDb.instance.deleteTxn(x.id!);
    s.bump();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final f = s.fmt;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.txn == null
            ? s.t('নতুন লেনদেন', 'New entry')
            : s.t('লেনদেন সম্পাদনা', 'Edit entry')),
        actions: [
          if (widget.txn != null)
            IconButton(
              tooltip: s.t('মুছুন', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'income',
                  label: Text(s.t('আয়', 'Income')),
                  icon: const Icon(Icons.add_circle_outline)),
              ButtonSegment(
                  value: 'expense',
                  label: Text(s.t('ব্যয়', 'Expense')),
                  icon: const Icon(Icons.remove_circle_outline)),
            ],
            selected: {_type},
            onSelectionChanged: (sel) => setState(() {
              _type = sel.first;
              _category = _categories.first;
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amount,
            autofocus: widget.txn == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.]'))],
            decoration: InputDecoration(
              labelText: s.t('টাকার পরিমাণ', 'Amount'),
              prefixText: '৳ ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Text(s.t('ক্যাটাগরি', 'Category'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in _categories)
              ChoiceChip(
                label: Text(categoryLabel(c, s.english)),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          const SizedBox(height: 18),
          if (s.accounts.length > 1) ...[
            DropdownButtonFormField<int>(
              value: s.accounts.any((a) => a.id == _accountId)
                  ? _accountId
                  : s.accounts.first.id,
              decoration: InputDecoration(
                labelText: s.t('অ্যাকাউন্ট', 'Account'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final a in s.accounts)
                  DropdownMenuItem(
                      value: a.id, child: Text(accountDisplayName(a.name, s.english))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _accountId = v);
              },
            ),
            const SizedBox(height: 14),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('তারিখ', 'Date')),
            subtitle: Text(f.day(_date)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.t('বিবরণ (ঐচ্ছিক)', 'Note (optional)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(s.t('সংরক্ষণ করুন', 'Save entry')),
          ),
        ]),
      ),
    );
  }
}
