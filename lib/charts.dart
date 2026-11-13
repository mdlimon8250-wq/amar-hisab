import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'db.dart';
import 'format.dart';
import 'l10n.dart';
import 'widgets.dart';

const chartPalette = <Color>[
  Color(0xFF2E9E6B), Color(0xFF3B82F6), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF14B8A6),
  Color(0xFFEC4899), Color(0xFF84CC16), Color(0xFF64748B),
];

/// Donut chart with tap-to-highlight and a legend (name, percent, amount).
class PieBreakdown extends StatefulWidget {
  final List<CatTotal> items;
  final AppState state;
  final String centerLabel;
  const PieBreakdown({
    super.key,
    required this.items,
    required this.state,
    required this.centerLabel,
  });
  @override
  State<PieBreakdown> createState() => _PieBreakdownState();
}

class _PieBreakdownState extends State<PieBreakdown> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final f = s.fmt;
    final items = widget.items;
    final total = items.fold<double>(0, (a, b) => a + b.amount);
    if (items.isEmpty || total <= 0) return const SizedBox.shrink();

    final centerTop = _touched >= 0 && _touched < items.length
        ? categoryLabel(items[_touched].category, s.english)
        : widget.centerLabel;
    final centerValue = _touched >= 0 && _touched < items.length
        ? items[_touched].amount
        : total;

    return Column(children: [
      SizedBox(
        height: 210,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 54,
            pieTouchData: PieTouchData(
              touchCallback: (event, resp) {
                final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                setState(() => _touched = event.isInterestedForInteractions ? i : -1);
              },
            ),
            sections: [
              for (var i = 0; i < items.length; i++)
                PieChartSectionData(
                  value: items[i].amount,
                  color: chartPalette[i % chartPalette.length],
                  radius: _touched == i ? 40 : 32,
                  showTitle: false,
                ),
            ],
          )),
          SizedBox(
            width: 96,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(centerTop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(f.money(centerValue),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: chartPalette[i % chartPalette.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(categoryLabel(items[i].category, s.english))),
            Text(f.digits('${(items[i].amount * 100 / total).toStringAsFixed(0)}%'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 12),
            Text(f.money(items[i].amount),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }
}

/// Grouped income / expense bars, one group per day. Touch a bar for its value.
class IncomeExpenseBars extends StatelessWidget {
  final List<DateTime> days;
  final Map<String, Totals> data;
  final AppState state;
  final String Function(int index, DateTime day) labelFor;
  const IncomeExpenseBars({
    super.key,
    required this.days,
    required this.data,
    required this.state,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    final f = state.fmt;
    final ic = incomeColor(context);
    final ec = expenseColor(context);
    var maxV = 0.0;
    for (final d in days) {
      final t = data[dateKey(d)] ?? Totals.zero;
      maxV = math.max(maxV, math.max(t.income, t.expense));
    }
    final width = days.length <= 7 ? 12.0 : (days.length <= 14 ? 8.0 : 4.0);
    return Column(children: [
      SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxV <= 0 ? 1 : maxV * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(labelFor(i, days[i]), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                f.money(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 1,
                barRods: [
                  BarChartRodData(
                    toY: (data[dateKey(days[i])] ?? Totals.zero).income,
                    color: ic,
                    width: width,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  BarChartRodData(
                    toY: (data[dateKey(days[i])] ?? Totals.zero).expense,
                    color: ec,
                    width: width,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
        )),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _dot(ic),
        const SizedBox(width: 6),
        Text(state.t('আয়', 'Income')),
        const SizedBox(width: 20),
        _dot(ec),
        const SizedBox(width: 6),
        Text(state.t('ব্যয়', 'Expense')),
      ]),
    ]);
  }

  Widget _dot(Color c) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      );
}
