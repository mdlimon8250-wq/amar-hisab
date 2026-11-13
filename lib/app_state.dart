import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';
import 'format.dart';
import 'l10n.dart';

/// App-wide settings + selected account. Listen to it for settings changes and
/// to [rev] for data changes (transactions / accounts edited).
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    english = _prefs.getBool('english') ?? false;
    final th = _prefs.getString('theme');
    if (th != null) {
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == th,
        orElse: () => ThemeMode.system,
      );
    } else if (_prefs.containsKey('dark')) {
      // setting saved by version 1 of the app
      themeMode = (_prefs.getBool('dark') ?? false) ? ThemeMode.dark : ThemeMode.light;
    }
  }

  final SharedPreferences _prefs;
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  bool english = false;
  ThemeMode themeMode = ThemeMode.system;
  List<Account> accounts = [];
  int? accountId; // null = all accounts
  String? loadError;

  String t(String bn, String en) => english ? en : bn;
  Fmt get fmt => Fmt(english);

  Account? accountById(int id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  String accountName(int id) {
    final a = accountById(id);
    return a == null ? '?' : accountDisplayName(a.name, english);
  }

  Future<void> load() async {
    try {
      await reloadAccounts();
    } catch (e) {
      loadError = '$e';
    }
  }

  Future<void> reloadAccounts() async {
    accounts = await HisabDb.instance.accounts();
    final stored = _prefs.containsKey('account') ? _prefs.getInt('account') : null;
    if (stored == -1) {
      accountId = null;
    } else if (stored != null && accounts.any((a) => a.id == stored)) {
      accountId = stored;
    } else {
      accountId = accounts.isEmpty ? null : accounts.first.id;
    }
    notifyListeners();
  }

  void setAccount(int? id) {
    accountId = id;
    _prefs.setInt('account', id ?? -1);
    notifyListeners();
  }

  void setEnglish(bool v) {
    english = v;
    _prefs.setBool('english', v);
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setString('theme', m.name);
    notifyListeners();
  }

  /// Call after any change to transactions or accounts.
  void bump() => rev.value++;
}
