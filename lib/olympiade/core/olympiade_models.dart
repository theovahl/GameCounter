import 'package:cloud_firestore/cloud_firestore.dart';
import '../olympiade_editions.dart';
import 'olympiade_edition.dart';

// Ergebnis-Wert für ein Unentschieden
const int olympiadeDraw = -1;

// Zuschauer-Seite (Firebase Hosting), siehe lib/main_live.dart
const String olympiadeLiveBaseUrl = 'https://game-counter-tv.web.app';

String olympiadeLiveUrl(String olympiadeId) => '$olympiadeLiveBaseUrl/?o=$olympiadeId';

// Eine der beiden WGs
class OlympiadeWg {
  final String name;
  final List<String> playerUids;
  final List<String> playerNames;

  OlympiadeWg({
    required this.name,
    required this.playerUids,
    required this.playerNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'playerUids': playerUids,
      'playerNames': playerNames,
    };
  }

  factory OlympiadeWg.fromMap(Map<String, dynamic> map) {
    return OlympiadeWg(
      name: map['name'] ?? '',
      playerUids: List<String>.from(map['playerUids'] ?? []),
      playerNames: List<String>.from(map['playerNames'] ?? []),
    );
  }
}

// Stand einer Disziplin: offen, läuft (Spiele verknüpft) oder entschieden (winnerWg gesetzt).
// Dart und Bierpong bestehen aus mehreren Spielen, deren Legs bzw. Siege in [tally] summiert werden.
class OlympiadeResult {
  final List<String> gameIds; // Verknüpfte Spiele im jeweiligen Modus (meist genau eins)
  final List<int> tally; // Mehrfach-Disziplinen: Legs bzw. Siege pro WG
  final bool lastGameActive; // Mehrfach-Disziplinen: letztes Spiel läuft noch
  final int? winnerWg; // 0, 1 oder olympiadeDraw; null = noch nicht entschieden

  const OlympiadeResult({
    this.gameIds = const [],
    this.tally = const [0, 0],
    this.lastGameActive = false,
    this.winnerWg,
  });

  // Das zuletzt verknüpfte Spiel
  String? get gameId => gameIds.isEmpty ? null : gameIds.last;

  bool get isOpen => gameIds.isEmpty && winnerWg == null;
  bool get isRunning => gameIds.isNotEmpty && winnerWg == null;
  bool get isDone => winnerWg != null;

  bool sameAs(OlympiadeResult other) {
    return winnerWg == other.winnerWg &&
        lastGameActive == other.lastGameActive &&
        gameIds.join(',') == other.gameIds.join(',') &&
        tally.join(',') == other.tally.join(',');
  }

  Map<String, dynamic> toMap() {
    return {
      'gameIds': gameIds,
      'tally': tally,
      'lastGameActive': lastGameActive,
      'winnerWg': winnerWg,
    };
  }

  factory OlympiadeResult.fromMap(Map<String, dynamic> map) {
    final tallyRaw = (map['tally'] as List<dynamic>?) ?? [];
    return OlympiadeResult(
      gameIds: map['gameIds'] != null
          ? List<String>.from(map['gameIds'])
          // Ältere Olympiaden speicherten nur eine einzelne gameId
          : [if (map['gameId'] is String) map['gameId'] as String],
      tally: tallyRaw.length == 2 ? tallyRaw.map((e) => (e as num).toInt()).toList() : const [0, 0],
      lastGameActive: map['lastGameActive'] == true,
      winnerWg: (map['winnerWg'] as num?)?.toInt(),
    );
  }
}

// Repräsentiert eine komplette WG Olympiade
class OlympiadeGame {
  final String? id; // Firestore Document ID
  final String editionId; // Ausgabe (Regeln & Zeitplan), siehe olympiade_editions.dart
  final String createdBy;
  final DateTime date;
  final List<String> memberUids; // Alle Mitglieder beider WGs + Ersteller (für Abfragen)
  final List<OlympiadeWg> wgs; // Genau 2
  final List<String> disciplines; // Ausgewählte Disziplinen in Anzeigereihenfolge
  final Map<String, OlympiadeResult> results;
  final String status; // 'active' | 'finished'
  // true: Spiele liegen getrennt von den normalen Modi unter olympiade_games/<id>/...
  // (ältere Olympiaden: false, Spiele in den normalen Collections der Modi)
  final bool separateGames;

  OlympiadeGame({
    this.id,
    this.editionId = olympiadeDefaultEditionId,
    required this.createdBy,
    required this.date,
    required this.memberUids,
    required this.wgs,
    required this.disciplines,
    Map<String, OlympiadeResult>? results,
    this.status = 'active',
    this.separateGames = false,
  }) : results = results ?? {};

  OlympiadeResult resultFor(String discipline) => results[discipline] ?? const OlympiadeResult();

  int get doneCount => disciplines.where((d) => resultFor(d).isDone).length;
  int get remainingCount => disciplines.length - doneCount;

  // Punkte pro WG: Sieg = 1, Unentschieden = 0,5
  List<double> get points {
    final result = [0.0, 0.0];
    for (final d in disciplines) {
      final winner = resultFor(d).winnerWg;
      if (winner == 0 || winner == 1) {
        result[winner!] += 1;
      } else if (winner == olympiadeDraw) {
        result[0] += 0.5;
        result[1] += 0.5;
      }
    }
    return result;
  }

  // WG, die uneinholbar vorne liegt (null = noch offen bzw. Gleichstand)
  int? get decidedWinner {
    final p = points;
    final remaining = remainingCount;
    if (p[0] > p[1] + remaining) return 0;
    if (p[1] > p[0] + remaining) return 1;
    return null;
  }

  bool get allDone => remainingCount == 0;

  OlympiadeEdition get edition => olympiadeEditionById(editionId);

  OlympiadeGame copyWithResult(String discipline, OlympiadeResult result) {
    return OlympiadeGame(
      id: id,
      editionId: editionId,
      createdBy: createdBy,
      date: date,
      memberUids: memberUids,
      wgs: wgs,
      disciplines: disciplines,
      results: {...results, discipline: result},
      status: status,
      separateGames: separateGames,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'editionId': editionId,
      'createdBy': createdBy,
      'date': Timestamp.fromDate(date),
      'memberUids': memberUids,
      'wgs': wgs.map((w) => w.toMap()).toList(),
      'disciplines': disciplines,
      'results': results.map((k, v) => MapEntry(k, v.toMap())),
      'status': status,
      'separateGames': separateGames,
    };
  }

  factory OlympiadeGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OlympiadeGame.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory OlympiadeGame.fromMap(Map<String, dynamic> data, {String? id}) {
    final wgsRaw = (data['wgs'] as List<dynamic>?) ?? [];
    final resultsRaw = (data['results'] as Map<String, dynamic>?) ?? {};
    return OlympiadeGame(
      id: id,
      editionId: data['editionId'] ?? olympiadeDefaultEditionId,
      createdBy: data['createdBy'] ?? '',
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      wgs: wgsRaw.map((w) => OlympiadeWg.fromMap(Map<String, dynamic>.from(w as Map))).toList(),
      disciplines: List<String>.from(
        data['disciplines'] ?? olympiadeEditionById(data['editionId'] as String?).disciplineKeys,
      ),
      results: resultsRaw.map(
        (k, v) => MapEntry(k, OlympiadeResult.fromMap(Map<String, dynamic>.from(v as Map))),
      ),
      status: data['status'] ?? 'active',
      separateGames: data['separateGames'] == true,
    );
  }
}

// Formatiert Punkte ohne unnötige Nachkommastellen (z.B. 3 oder 3,5)
String formatOlympiadePoints(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
