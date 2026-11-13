import 'package:flutter/material.dart';

import 'app_state.dart';
import 'charts.dart';
import 'db.dart';
import 'format.dart';
import 'report_logic.dart';
import 'txn_form.dart';
import 'widgets.dart';

class DashboardPage extends StatefulWidget {
  final AppState state;
  final VoidCallback onSeeAll;
  const DashboardPage({super.key, required this.state, required this.onSeeAll});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Listenable _listenable;
  int _seq = 0;
  bool _loading = true;
  String? _error;
  Totals _all = Totals.zero;
  Totals _month = Totals.zero;
  List<CatTotal> _cats = [];
  Map<String, Totals> _week = {};
  List<Txn> _recent = [];
  late DateRange _weekRange;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _weekRange = _computeWeek();
    _listenable = Listenable.merge([s, s.rev]);
    _listenable.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _listenable.removeListener(_reload);
    super.dispose();
  }

  DateRange _computeWeek() {
    final now = DateTime.now();
    return DateRange(DateTime(now.year, now.month, now.day - 6), dateOnly(now));
  }

  Future<void> _reload() async {
    final seq = ++_seq;
    try {
      final db = HisabDb.instance;
      final id = s.accountId;
      final m = rangeFor(Period.monthly, DateTime.now());
      final w = _computeWeek();
      final all = await db.totals(accountId: id);
      final month = await db.totals(accountId: id, from: m.fromKey, to: m.toKey);
      final cats = await db.categoryTotals(
          type: 'expense', accountId: id, from: m.fromKey, to: m.toKey);
      final week = await db.dailyTotals(accountId: id, from: w.fromKey, to: w.toKey);
      final recent = await db.transactions(accountId: id, limit: 6);
      if (!mounted || seq != _seq) return;
      setState(() {
        _all = all;
        _month = month;
        _cats = cats;
        _week = week;
        _recent = recent;
        _weekRange = w;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final f = s.fmt;
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF087F5B), Color(0xFF0B5D48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('বর্তমান ব্যালেন্স', 'Current balance'),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(f.money(_all.net),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.t('মোট আয়', 'Total income')}: ${f.money(_all.income)}  •  '
                '${s.t('মোট ব্যয়', 'Total expense')}: ${f.money(_all.expense)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
          SectionTitle('${s.t('এই মাস', 'This month')} • ${f.monthYear(DateTime.now())}'),
          Row(children: [
            Expanded(
              child: SummaryCard(
                title: s.t('আয়', 'Income'),
                value: f.money(_month.income),
                icon: Icons.trending_up,
                color: incomeColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: s.t('ব্যয়', 'Expenses'),
                value: f.money(_month.expense),
                icon: Icons.trending_down,
                color: expenseColor(context),
              ),
            ),
          ]),
          if (_cats.isNotEmpty) ...[
            SectionTitle(s.t('এই মাসের খরচের ধরন', 'Spending by category (this month)')),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PieBreakdown(
                    items: _cats, state: s, centerLabel: s.t('মোট ব্যয়', 'Total')),
              ),
            ),
          ],
          SectionTitle(s.t('শেষ ৭ দিন', 'Last 7 days')),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IncomeExpenseBars(
                days: _weekRange.days,
                data: _week,
                state: s,
                labelFor: (i, d) => f.weekdayShort(d),
              ),
            ),
          ),
          Row(children: [
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 8),
              child: Text(s.t('সাম্প্রতিক লেনদেন', 'Recent transactions'),
                  style: Theme.of(context).textTheme.titleMedium),
            )),
            if (_recent.isNotEmpty)
              TextButton(onPressed: widget.onSeeAll, child: Text(s.t('সব দেখুন', 'See all'))),
          ]),
          if (_recent.isEmpty)
            SizedBox(height: 200, child: EmptyState(s))
          else
            for (final x in _recent)
              TxnTile(
                txn: x,
                state: s,
                showAccount: s.accountId == null,
                onTap: () => openTxnForm(context, s, x),
              ),
          if (_recent.isNotEmpty) Divider(color: scheme.outlineVariant, height: 1),
        ],
      ),
    );
  }
}
