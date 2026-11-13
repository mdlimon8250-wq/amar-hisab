import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'dashboard_page.dart';
import 'entries_page.dart';
import 'l10n.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'txn_form.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  await state.load();
  runApp(AmarHisabApp(state: state));
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: light ? const Color(0xFF087F5B) : const Color(0xFF45B68A),
      brightness: b,
    ),
    scaffoldBackgroundColor: light ? const Color(0xFFF6F8F7) : null,
  );
}

class AmarHisabApp extends StatelessWidget {
  final AppState state;
  const AmarHisabApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Amar Hisab',
          themeMode: state.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: HomeShell(state: state),
        ),
      );
}

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  AppState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    if (s.loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${s.t('ডেটাবেজ খোলা যায়নি', 'Could not open database')}\n${s.loadError}',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final pages = <Widget>[
      DashboardPage(state: s, onSeeAll: () => setState(() => _tab = 1)),
      EntriesPage(state: s),
      ReportsPage(state: s),
      SettingsPage(state: s),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('আমার হিসাব', 'Amar Hisab'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (s.accounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButton<int>(
                value: s.accountId ?? -1,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: -1, child: Text(s.t('সব অ্যাকাউন্ট', 'All accounts'))),
                  for (final a in s.accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(accountDisplayName(a.name, s.english),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) s.setAccount(v == -1 ? null : v);
                },
              ),
            ),
        ],
      ),
      body: pages[_tab],
      floatingActionButton: _tab < 2
          ? FloatingActionButton.extended(
              onPressed: () => openTxnForm(context, s),
              icon: const Icon(Icons.add),
              label: Text(s.t('নতুন হিসাব', 'Add entry')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.t('হোম', 'Home')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: s.t('লেনদেন', 'Entries')),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: s.t('রিপোর্ট', 'Reports')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s.t('সেটিংস', 'Settings')),
        ],
      ),
    );
  }
}
