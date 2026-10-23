import 'package:flutter/material.dart';
import 'olympiade_models.dart';
import 'olympiade_disciplines.dart';

/// Medaillenspiegel der WG Olympiade: Punkte beider WGs, gewonnene Disziplinen,
/// Fortschritt und Status. Wird in der App und auf der Zuschauer-Seite verwendet.
class OlympiadeScoreboard extends StatelessWidget {
  final OlympiadeGame olympiade;
  final double scale; // > 1 für große Bildschirme / Beamer

  const OlympiadeScoreboard({super.key, required this.olympiade, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final points = olympiade.points;
    final bool isOver = olympiade.status == 'finished' || olympiade.allDone;
    final int leader = olympiadeLeader(points);
    final int? decided = olympiade.decidedWinner;

    String headline;
    Color headlineColor;
    IconData headlineIcon;
    if (isOver) {
      headline = leader == olympiadeDraw
          ? 'Unentschieden – beide WGs sind Sieger!'
          : '${olympiade.wgs[leader].name} gewinnt die WG Olympiade!';
      headlineColor = leader == olympiadeDraw ? Colors.white : olympiadeWgColors[leader];
      headlineIcon = Icons.emoji_events;
    } else if (decided != null) {
      headline = '${olympiade.wgs[decided].name} ist nicht mehr einzuholen!';
      headlineColor = olympiadeWgColors[decided];
      headlineIcon = Icons.emoji_events_outlined;
    } else if (leader == olympiadeDraw) {
      headline = 'Gleichstand';
      headlineColor = Colors.white70;
      headlineIcon = Icons.balance;
    } else {
      headline = '${olympiade.wgs[leader].name} führt';
      headlineColor = olympiadeWgColors[leader];
      headlineIcon = Icons.trending_up;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            olympiadeWgColors[0].withValues(alpha: 0.22),
            const Color(0xFF1E1E1E),
            olympiadeWgColors[1].withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 1.5),
      ),
      padding: EdgeInsets.all(16.0 * scale),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amberAccent, size: 20 * scale),
              const SizedBox(width: 6),
              Text(
                'MEDAILLENSPIEGEL',
                style: TextStyle(
                  fontSize: 12 * scale,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildWgColumn(0, points[0])),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0 * scale),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ':',
                        style: TextStyle(
                          fontSize: 40 * scale,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        '${olympiade.doneCount}/${olympiade.disciplines.length}',
                        style: TextStyle(fontSize: 12 * scale, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildWgColumn(1, points[1])),
              ],
            ),
          ),
          SizedBox(height: 14 * scale),

          // Fortschritt: ein Segment pro Disziplin
          Row(
            children: olympiade.disciplines.map((d) {
              final winner = olympiade.resultFor(d).winnerWg;
              final color = winner == 0 || winner == 1
                  ? olympiadeWgColors[winner!]
                  : (winner == olympiadeDraw ? Colors.white54 : Colors.grey.shade800);
              return Expanded(
                child: Container(
                  height: 6 * scale,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3 * scale),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 14 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(headlineIcon, color: headlineColor, size: 20 * scale),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                    color: headlineColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWgColumn(int wgIndex, double points) {
    final wg = olympiade.wgs[wgIndex];
    final color = olympiadeWgColors[wgIndex];
    final won = olympiade.disciplines.where((d) => olympiade.resultFor(d).winnerWg == wgIndex);

    return Column(
      children: [
        Text(
          wg.name,
          style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          wg.playerNames.join(', '),
          style: TextStyle(fontSize: 11 * scale, color: Colors.white60),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 6 * scale),
        Text(
          formatOlympiadePoints(points),
          style: TextStyle(fontSize: 52 * scale, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 4 * scale),
        // Gewonnene Disziplinen als "Medaillen"
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: won.map((d) {
            final info = olympiadeDiscipline(d);
            return Tooltip(
              message: info.name,
              child: CircleAvatar(
                radius: 13 * scale,
                backgroundColor: color.withValues(alpha: 0.25),
                child: Icon(info.icon, size: 15 * scale, color: color),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
