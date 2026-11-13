import 'package:amar_hisab/app_state.dart';
import 'package:amar_hisab/charts.dart';
import 'package:amar_hisab/db.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('charts render with data in English', (tester) async {
    SharedPreferences.setMockInitialValues({'english': true});
    final state = AppState(await SharedPreferences.getInstance());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            PieBreakdown(
              items: const [CatTotal('food', 300), CatTotal('rent', 700)],
              state: state,
              centerLabel: 'Total',
            ),
            IncomeExpenseBars(
              days: [DateTime(2026, 11, 1), DateTime(2026, 11, 2)],
              data: const {'2026-11-01': Totals(100, 40)},
              state: state,
              labelFor: (i, d) => '${d.day}',
            ),
          ]),
        ),
      ),
    ));

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('৳1,000'), findsOneWidget);
  });

  test('settings: legacy dark flag and language are read', () async {
    SharedPreferences.setMockInitialValues({'dark': true, 'english': true});
    final state = AppState(await SharedPreferences.getInstance());
    expect(state.themeMode, ThemeMode.dark);
    expect(state.english, isTrue);
    expect(state.t('বাংলা', 'English'), 'English');
  });
}
