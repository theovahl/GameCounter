import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/app_theme.dart';
import 'package:game_counter/olympiade/olympiade_editions.dart';
import 'package:game_counter/olympiade/olympiade_editions_screen.dart';
import 'package:game_counter/olympiade/olympiade_info_widgets.dart';
import 'package:game_counter/olympiade/olympiade_models.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: child));
}

void main() {
  final edition = olympiadeEditionById('2026-4');

  for (final size in const [Size(360, 800), Size(1400, 900)]) {
    testWidgets('rules and schedule render without overflow at ${size.width.toInt()}px', (tester) async {
      await _pumpAt(
        tester,
        size,
        // SingleChildScrollView baut alles (auch außerhalb des Bildschirms) und prüft so jede Zeile
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                OlympiadeRulesList(edition: edition, scale: size.width > 900 ? 1.15 : 1.0),
                OlympiadeScheduleList(edition: edition, scale: size.width > 900 ? 1.15 : 1.0),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Das Große Teilen'), findsNWidgets(2)); // Regeln + Zeitplan
      expect(find.text('Codenames mit Pizza :D'), findsOneWidget);
    });
  }

  testWidgets('schedule marks decided disciplines with a trophy', (tester) async {
    final olympiade = OlympiadeGame(
      editionId: edition.id,
      createdBy: 'u1',
      date: DateTime(2026, 10, 23),
      memberUids: ['u1'],
      wgs: [
        OlympiadeWg(name: 'A', playerUids: ['u1'], playerNames: ['Theo']),
        OlympiadeWg(name: 'B', playerUids: ['u2'], playerNames: ['Max']),
      ],
      disciplines: edition.disciplines,
      results: {'boule': const OlympiadeResult(winnerWg: 0)},
    );
    await _pumpAt(
      tester,
      const Size(360, 800),
      Scaffold(body: ListView(children: [OlympiadeScheduleList(edition: edition, olympiade: olympiade)])),
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
  });

  testWidgets('edition selection lists the 2026 edition', (tester) async {
    await _pumpAt(tester, const Size(360, 800), const OlympiadeEditionsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('WG Olympiade 2026'), findsOneWidget);
    expect(find.text('4. Ausgabe'), findsOneWidget);
  });
}
