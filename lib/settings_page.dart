import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'backup.dart';
import 'db.dart';
import 'l10n.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  AppState get s => state;

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addAccount(BuildContext context) async {
    final r = await showDialog<AccountInput>(
        context: context, builder: (_) => AccountDialog(state: s));
    if (r == null) return;
    await HisabDb.instance.addAccount(r.name, r.kind);
    await s.reloadAccounts();
    s.bump();
  }

  Future<void> _editAccount(BuildContext context, Account a) async {
    final r = await showDialog<AccountInput>(
        context: context, builder: (_) => AccountDialog(state: s, existing: a));
    if (r == null) return;
    await HisabDb.instance.updateAccount(a.id, r.name, r.kind);
    await s.reloadAccounts();
    s.bump();
  }

  Future<void> _deleteAccount(BuildContext context, Account a) async {
    if (s.accounts.length <= 1) {
      _snack(context, s.t('কমপক্ষে একটি অ্যাকাউন্ট থাকতে হবে', 'At least one account is required'));
      return;
    }
    final yes = await confirmDialog(
      context,
      title: s.t('অ্যাকাউন্ট মুছবেন?', 'Delete account?'),
      body: s.t(
        '"${accountDisplayName(a.name, false)}" এবং এর সব লেনদেন স্থায়ীভাবে মুছে যাবে।',
        '"${accountDisplayName(a.name, true)}" and all of its entries will be permanently deleted.',
      ),
      ok: s.t('মুছুন', 'Delete'),
      cancel: s.t('না', 'Cancel'),
    );
    if (!yes) return;
    await HisabDb.instance.deleteAccount(a.id);
    await s.reloadAccounts();
    s.bump();
  }

  Future<void> _backup(BuildContext context) async {
    final db = HisabDb.instance;
    final text = encodeBackup(await db.accounts(), await db.allTransactions());
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      _snack(
          context,
          s.t('ব্যাকআপ কপি হয়েছে। এটি নোট/মেসেজ/ইমেইলে পেস্ট করে সংরক্ষণ করুন।',
              'Backup copied. Paste it into Notes / a message / email to keep it safe.'));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final text = await showDialog<String>(
        context: context, builder: (_) => RestoreDialog(state: s));
    if (text == null || !context.mounted) return;
    final BackupData data;
    try {
      data = decodeBackup(text);
    } on FormatException {
      _snack(context, s.t('ব্যাকআপটি সঠিক নয়। কিছু পরিবর্তন হয়নি।',
          'That is not a valid backup. Nothing was changed.'));
      return;
    }
    if (!context.mounted) return;
    final yes = await confirmDialog(
      context,
      title: s.t('বর্তমান সব ডেটা প্রতিস্থাপন করবেন?', 'Replace all current data?'),
      body: s.t(
        'ব্যাকআপে ${data.accounts.length}টি অ্যাকাউন্ট ও ${data.txns.length}টি লেনদেন আছে। বর্তমান সব ডেটা মুছে এগুলো বসানো হবে।',
        'The backup has ${data.accounts.length} accounts and ${data.txns.length} entries. All current data will be replaced.',
      ),
      ok: s.t('ফিরিয়ে আনুন', 'Restore'),
      cancel: s.t('না', 'Cancel'),
    );
    if (!yes) return;
    try {
      await HisabDb.instance.replaceAll(data.accounts, data.txns);
      await s.reloadAccounts();
      s.bump();
      if (context.mounted) _snack(context, s.t('ডেটা ফিরিয়ে আনা হয়েছে', 'Data restored'));
    } catch (_) {
      if (context.mounted) {
        _snack(context, s.t('ফিরিয়ে আনা যায়নি। আগের ডেটা অক্ষত আছে।',
            'Restore failed. Your previous data is unchanged.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Text(s.t('সেটিংস', 'Settings'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Text(s.t('ভাষা', 'Language'), style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('বাংলা')),
          ButtonSegment(value: true, label: Text('English')),
        ],
        selected: {s.english},
        onSelectionChanged: (sel) => s.setEnglish(sel.first),
      ),
      const SizedBox(height: 18),
      Text(s.t('থিম', 'Theme'), style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
              value: ThemeMode.system,
              icon: const Icon(Icons.brightness_auto),
              label: Text(s.t('অটো', 'Auto'))),
          ButtonSegment(
              value: ThemeMode.light,
              icon: const Icon(Icons.light_mode_outlined),
              label: Text(s.t('লাইট', 'Light'))),
          ButtonSegment(
              value: ThemeMode.dark,
              icon: const Icon(Icons.dark_mode_outlined),
              label: Text(s.t('ডার্ক', 'Dark'))),
        ],
        selected: {s.themeMode},
        onSelectionChanged: (sel) => s.setThemeMode(sel.first),
      ),
      SectionTitle(s.t('অ্যাকাউন্ট', 'Accounts')),
      for (final a in s.accounts)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(kindIcon(a.kind)),
            title: Text(accountDisplayName(a.name, s.english)),
            subtitle: Text(kindLabel(a.kind, s.english)),
            onTap: () => _editAccount(context, a),
            trailing: IconButton(
              tooltip: s.t('মুছুন', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteAccount(context, a),
            ),
          ),
        ),
      ListTile(
        leading: const Icon(Icons.add_circle_outline),
        title: Text(s.t('নতুন অ্যাকাউন্ট যোগ করুন', 'Add account')),
        onTap: () => _addAccount(context),
      ),
      SectionTitle(s.t('ব্যাকআপ ও রিস্টোর', 'Backup & restore')),
      Card(
        margin: EdgeInsets.zero,
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: Text(s.t('ব্যাকআপ কপি করুন', 'Copy backup')),
            subtitle: Text(s.t('সব ডেটা টেক্সট হিসেবে ক্লিপবোর্ডে', 'All data as text to clipboard')),
            onTap: () => _backup(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(s.t('ব্যাকআপ থেকে ফিরিয়ে আনুন', 'Restore from backup')),
            subtitle: Text(s.t('কপি করা ব্যাকআপ পেস্ট করুন', 'Paste a copied backup')),
            onTap: () => _restore(context),
          ),
        ]),
      ),
      SectionTitle(s.t('অ্যাপ সম্পর্কে', 'About')),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(s.t('আমার হিসাব', 'Amar Hisab')),
        subtitle: const Text('v1.1.0 • Offline-first • BDT ৳'),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          s.t('ডেটা শুধু এই ফোনেই থাকে, কোনো সার্ভারে যায় না। অ্যাপ আনইনস্টল করলে ডেটা মুছে যাবে; তাই নিয়মিত ব্যাকআপ রাখুন।',
              'Your data stays on this phone only and is never sent to any server. Uninstalling the app deletes it, so back up regularly.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ]);
  }
}
