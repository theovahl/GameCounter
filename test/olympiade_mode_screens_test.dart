import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_counter/app_theme.dart';
import 'package:game_counter/olympiade/ausgabe_2026/geoguessr/geoguessr_discipline.dart';
import 'package:game_counter/olympiade/ausgabe_2026/geoguessr/geoguessr_models.dart';
import 'package:game_counter/olympiade/ausgabe_2026/geoguessr/geoguessr_score_screen.dart';
import 'package:game_counter/olympiade/ausgabe_2026/halbieren/halbieren_discipline.dart';
import 'package:game_counter/olympiade/ausgabe_2026/halbieren/halbieren_models.dart';
import 'package:game_counter/olympiade/ausgabe_2026/halbieren/halbieren_score_screen.dart';
import 'package:game_counter/olympiade/olympiade_editions.dart';

// Spiele ohne id werden ohne Firestore angezeigt, so lässt sich das Layout prüfen
Future<void> _pumpPhone(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
}

void main() {
  final edition = olympiadeEditionById(olympiadeDefaultEditionId);

  testWidgets('Das Große Teilen shows the current food, timer and act note', (tester) async {
    final foods = (edition.discipline('halbieren') as TeilenOlympiadeDiscipline).foods;
    final game = HalbierenGame(
      createdBy: 'u1',
      date: DateTime(2026, 10, 23),
      memberUids: ['u1', 'u2'],
      teams: [
        HalbierenTeam(name: 'Unsere WG', playerUids: ['u1', 'u2', 'u5'], playerNames: ['Theo', 'Anna', 'Lea']),
        HalbierenTeam(name: 'Gegner-WG', playerUids: ['u3', 'u4', 'u6'], playerNames: ['Max', 'Ben', 'Tom']),
      ],
      foods: foods,
      entries: [
        for (int f = 0; f < 3; f++) ...[
          TeilenEntry(foodIndex: f, teamIndex: 0, deviation: 2.5, cutterUid: 'u1'),
          TeilenEntry(foodIndex: f, teamIndex: 1, deviation: 4, cutterUid: 'u3'),
        ],
      ],
    );
    await _pumpPhone(tester, HalbierenScoreScreen(game: game));

    expect(tester.takeException(), isNull);
    expect(foods.length, 9);
    // Viertes Lebensmittel = erstes im zweiten Akt
    expect(find.text('Ingwerknolle'), findsWidgets);
    expect(find.text('Nur schwache Hand'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('7,5 %'), findsOneWidget);
  });

  testWidgets('GeoGuessr shows the current stage', (tester) async {
    final game = GeoguessrGame(
      createdBy: 'u1',
      date: DateTime(2026, 10, 23),
      memberUids: ['u1', 'u2'],
      teams: [
        GeoguessrTeam(name: 'Unsere WG', playerUids: ['u1'], playerNames: ['Theo']),
        GeoguessrTeam(name: 'Gegner-WG', playerUids: ['u2'], playerNames: ['Max']),
      ],
      stages: (edition.discipline('geoguessr') as GeoguessrOlympiadeDiscipline)
          .stages
          .map((s) => GeoguessrStage(title: s.title, details: s.details, winsNeeded: s.winsNeeded))
          .toList(),
      rounds: [
        GeoguessrRound(stageIndex: 0, winnerIndex: 0),
        GeoguessrRound(stageIndex: 0, winnerIndex: 0),
      ],
    );
    await _pumpPhone(tester, GeoguessrScoreScreen(game: game));

    expect(tester.takeException(), isNull);
    expect(find.text('Stufe 2 von 3'), findsOneWidget);
    expect(find.text('Weltkarte · No-Move'), findsOneWidget);
  });
}
