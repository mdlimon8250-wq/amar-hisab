import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'db.dart';
import 'l10n.dart';

Color incomeColor(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF5BD39A)
    : const Color(0xFF1E8E5A);

Color expenseColor(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFFFF8A80)
    : const Color(0xFFD64545);

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final AppState state;
  const EmptyState(this.state, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            Text(state.t('এখনো কোনো লেনদেন নেই', 'No transactions yet')),
            const SizedBox(height: 6),
            Text(
              state.t('নিচের বাটনে চাপ দিয়ে প্রথম হিসাব যোগ করুন।',
                  'Tap the button below to add your first entry.'),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}

class TxnTile extends StatelessWidget {
  final Txn txn;
  final AppState state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showAccount;
  const TxnTile({
    super.key,
    required this.txn,
    required this.state,
    required this.onTap,
    this.onLongPress,
    this.showAccount = false,
  });

  @override
  Widget build(BuildContext context) {
    final inc = txn.type == 'income';
    final color = inc ? incomeColor(context) : expenseColor(context);
    final f = state.fmt;
    final sub = <String>[f.dateLabel(txn.date)];
    if (showAccount) sub.add(state.accountName(txn.accountId));
    if (txn.note.isNotEmpty) sub.add(txn.note);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(36),
          child: Icon(inc ? Icons.south_west : Icons.north_east, color: color, size: 20),
        ),
        title: Text(categoryLabel(txn.category, state.english),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('${inc ? '+' : '−'}${f.money(txn.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String ok,
  required String cancel,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

class AccountInput {
  final String name;
  final String kind;
  const AccountInput(this.name, this.kind);
}

/// Add / edit an account. Owns its text controller so it is disposed safely.
class AccountDialog extends StatefulWidget {
  final AppState state;
  final Account? existing;
  const AccountDialog({super.key, required this.state, this.existing});
  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  late final TextEditingController _c;
  late String _kind;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.existing?.name ?? '');
    _kind = widget.existing?.kind ?? 'personal';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _c.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, AccountInput(name, _kind));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return AlertDialog(
      title: Text(widget.existing == null
          ? s.t('নতুন অ্যাকাউন্ট', 'New account')
          : s.t('অ্যাকাউন্ট সম্পাদনা', 'Edit account')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _c,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: s.t('অ্যাকাউন্টের নাম', 'Account name'),
            hintText: s.t('যেমন: দোকান', 'e.g. Shop'),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _kind,
          decoration: InputDecoration(labelText: s.t('ধরন', 'Type')),
          items: [
            for (final k in accountKinds)
              DropdownMenuItem(value: k, child: Text(kindLabel(k, s.english))),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _kind = v);
          },
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.t('বাতিল', 'Cancel'))),
        FilledButton(onPressed: _submit, child: Text(s.t('সংরক্ষণ', 'Save'))),
      ],
    );
  }
}

/// Lets the user paste backup text. Returns the text, or null if cancelled.
class RestoreDialog extends StatefulWidget {
  final AppState state;
  const RestoreDialog({super.key, required this.state});
  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (!mounted) return;
    if (d?.text != null) setState(() => _c.text = d!.text!);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return AlertDialog(
      title: Text(s.t('ব্যাকআপ থেকে ফিরিয়ে আনুন', 'Restore from backup')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s.t('আগে কপি করা ব্যাকআপ টেক্সট এখানে পেস্ট করুন।',
            'Paste the backup text you copied earlier.')),
        const SizedBox(height: 10),
        TextField(
          controller: _c,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: Text(s.t('পেস্ট', 'Paste'))),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(s.t('বাতিল', 'Cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(s.t('ফিরিয়ে আনুন', 'Restore'))),
      ],
    );
  }
}
