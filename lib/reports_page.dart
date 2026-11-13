import 'package:flutter/material.dart';

import 'app_state.dart';
import 'charts.dart';
import 'db.dart';
import 'report_logic.dart';
import 'widgets.dart';

class ReportsPage extends StatefulWidget {
  final AppState state;
  const ReportsPage({super.key, required this.state});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final Listenable _listenable;
  int _seq = 0;
  bool _loading = true;
  String? _error;

  Period _period = Period.monthly;
  DateTime _anchor = DateTime.now();
  String _pieType = 'expense';

  Totals _totals = Totals.zero;
  Map<String, Totals> _daily = {};
  List<CatTotal> _cats = [];

  AppState get s => widget.state;
  DateRange get _range => rangeFor(_period, _anchor);

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
      final db = HisabDb.instance;
      final r = _range;
      final id = s.accountId;
      final totals = await db.totals(accountId: id, from: r.fromKey, to: r.toKey);
      final daily = await db.dailyTotals(accountId: id, from: r.fromKey, to: r.toKey);
      final cats = await db.categoryTotals(
          type: _pieType, accountId: id, from: r.fromKey, to: r.toKey);
      if (!mounted || seq != _seq) return;
      setState(() {
        _totals = totals;
        _daily = daily;
        _cats = cats;
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

  void _change(void Function() fn) {
    setState(fn);
    _reload();
  }

  String _rangeLabel() {
    final f = s.fmt;
    final r = _range;
    switch (_period) {
      case Period.daily:
        return f.day(r.from);
      case Period.weekly:
        return '${f.dayMonth(r.from)} – ${f.dayMonth(r.to)} ${f.digits('${r.to.year}')}';
      case Period.monthly:
        return f.monthYear(r.from);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = s.fmt;
    final days = _range.days;
    final dayCount = days.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SegmentedButton<Period>(
          segments: [
            ButtonSegment(value: Period.daily, label: Text(s.t('দৈনিক', 'Daily'))),
            ButtonSegment(value: Period.weekly, label: Text(s.t('সাপ্তাহিক', 'Weekly'))),
            ButtonSegment(value: Period.monthly, label: Text(s.t('মাসিক', 'Monthly'))),
          ],
          selected: {_period},
          onSelectionChanged: (sel) => _change(() => _period = sel.first),
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(
            tooltip: s.t('আগের', 'Previous'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _change(() => _anchor = shiftAnchor(_period, _anchor, -1)),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => _change(() => _anchor = DateTime.now()),
              child: Text(_rangeLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            tooltip: s.t('পরের', 'Next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _change(() => _anchor = shiftAnchor(_period, _anchor, 1)),
          ),
        ]),
        const SizedBox(height: 8),
        if (_error != null)
          Center(child: Text(_error!))
        else if (_loading)
          const Padding(
              padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else ...[
          Row(children: [
            Expanded(
              child: SummaryCard(
                title: s.t('মোট আয়', 'Total income'),
                value: f.money(_totals.income),
                icon: Icons.trending_up,
                color: incomeColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: s.t('মোট ব্যয়', 'Total expenses'),
                value: f.money(_totals.expense),
                icon: Icons.trending_down,
                color: expenseColor(context),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SummaryCard(
            title: s.t('নিট ব্যালেন্স', 'Net balance'),
            value: f.money(_totals.net),
            icon: Icons.account_balance_wallet,
            color: Theme.of(context).colorScheme.primary,
          ),
          if (dayCount > 1 && _totals.expense > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '${s.t('দৈনিক গড় ব্যয়', 'Average daily expense')}: '
                '${f.money(_totals.expense / dayCount)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SectionTitle(s.t('আয় ও ব্যয়', 'Income & expense')),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IncomeExpenseBars(
                days: days,
                data: _daily,
                state: s,
                labelFor: (i, d) {
                  if (_period == Period.daily) return f.dayMonth(d);
                  if (_period == Period.weekly) return f.weekdayShort(d);
                  return (i == 0 || (i + 1) % 5 == 0) ? f.digits('${d.day}') : '';
                },
              ),
            ),
          ),
          SectionTitle(s.t('ক্যাটাগরি অনুযায়ী', 'By category')),
          Row(children: [
            ChoiceChip(
              label: Text(s.t('ব্যয়', 'Expense')),
              selected: _pieType == 'expense',
              onSelected: (_) => _change(() => _pieType = 'expense'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(s.t('আয়', 'Income')),
              selected: _pieType == 'income',
              onSelected: (_) => _change(() => _pieType = 'income'),
            ),
          ]),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _cats.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.t('এই সময়ে কোনো লেনদেন নেই', 'No entries in this period')),
                      ),
                    )
                  : PieBreakdown(
                      items: _cats,
                      state: s,
                      centerLabel: _pieType == 'expense'
                          ? s.t('মোট ব্যয়', 'Total')
                          : s.t('মোট আয়', 'Total'),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
