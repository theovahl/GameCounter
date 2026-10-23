import 'package:flutter/material.dart';
import 'olympiade_models.dart';
import 'olympiade_logic.dart';
import 'olympiade_edition.dart';

/// Regeln einer Disziplin als Karte (App, Startdialog und Zuschauer-Seite)
class OlympiadeRuleCard extends StatelessWidget {
  final OlympiadeEdition edition;
  final OlympiadeRuleSection section;
  final double scale;
  final bool showTitle;

  const OlympiadeRuleCard({
    super.key,
    required this.edition,
    required this.section,
    this.scale = 1.0,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final info = edition.discipline(section.discipline);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: info.color, width: 4)),
        ),
        padding: EdgeInsets.all(14 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Row(
                children: [
                  Icon(info.icon, color: info.color, size: 22 * scale),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale),
            ],
            ...section.items.map((item) => _buildItem(item, 0, info.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(OlympiadeRuleItem item, int depth, Color color) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0 * scale, top: 3 * scale, bottom: 3 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Icon(
                  depth == 0 ? Icons.circle : Icons.circle_outlined,
                  size: 7 * scale,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 14 * scale,
                    height: 1.35,
                    color: depth == 0 ? Colors.white : Colors.white70,
                    fontWeight: item.children.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          ...item.children.map((child) => _buildItem(child, depth + 1, color)),
        ],
      ),
    );
  }
}

/// Komplettes Regelwerk einer Ausgabe
class OlympiadeRulesList extends StatelessWidget {
  final OlympiadeEdition edition;
  final double scale;

  const OlympiadeRulesList({super.key, required this.edition, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: edition.rules
          .map((section) => OlympiadeRuleCard(edition: edition, section: section, scale: scale))
          .toList(),
    );
  }
}

/// Zeitplan einer Ausgabe. Mit [olympiade] werden laufende und entschiedene
/// Disziplinen markiert.
class OlympiadeScheduleList extends StatelessWidget {
  final OlympiadeEdition edition;
  final OlympiadeGame? olympiade;
  final double scale;

  const OlympiadeScheduleList({
    super.key,
    required this.edition,
    this.olympiade,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: edition.schedule.map((day) {
        return Padding(
          padding: EdgeInsets.only(bottom: 18 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  day.name,
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6 * scale),
                  child: Column(
                    children: day.entries.map((entry) => _buildEntry(entry)).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEntry(OlympiadeScheduleEntry entry) {
    final discipline = entry.discipline;
    final info = discipline != null ? edition.discipline(discipline) : null;
    final color = info?.color ?? Colors.grey;

    // Status der Disziplin in dieser Olympiade
    Widget? status;
    final o = olympiade;
    if (o != null && discipline != null && o.disciplines.contains(discipline)) {
      final result = o.resultFor(discipline);
      final winner = result.winnerWg;
      if (result.isDone && (winner == 0 || winner == 1)) {
        status = Tooltip(
          message: 'Sieg für ${o.wgs[winner!].name}',
          child: Icon(Icons.emoji_events, size: 20 * scale, color: olympiadeWgColors[winner]),
        );
      } else if (result.isDone) {
        status = Icon(Icons.handshake_outlined, size: 20 * scale, color: Colors.white70);
      } else if (result.isRunning) {
        status = Icon(Icons.play_circle, size: 20 * scale, color: Colors.redAccent);
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8 * scale),
      child: Row(
        children: [
          SizedBox(
            width: 108 * scale,
            child: Text(
              '${entry.start} – ${entry.end}',
              style: TextStyle(
                fontSize: 13 * scale,
                color: Colors.white70,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 4,
            height: 26 * scale,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: info != null ? 1 : 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (info != null) ...[
            Icon(info.icon, size: 18 * scale, color: color),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(
                fontSize: 15 * scale,
                fontWeight: info != null ? FontWeight.w600 : FontWeight.normal,
                color: info != null ? Colors.white : Colors.white60,
              ),
            ),
          ),
          ?status,
        ],
      ),
    );
  }
}

/// Regeln & Zeitplan einer Ausgabe als eigene Seite (aus einer laufenden Olympiade)
class OlympiadeInfoScreen extends StatelessWidget {
  final OlympiadeEdition edition;
  final OlympiadeGame? olympiade;
  final int initialTab;

  const OlympiadeInfoScreen({
    super.key,
    required this.edition,
    this.olympiade,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(edition.label),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Regeln'),
              Tab(icon: Icon(Icons.schedule), text: 'Zeitplan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [OlympiadeRulesList(edition: edition)],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [OlympiadeScheduleList(edition: edition, olympiade: olympiade)],
            ),
          ],
        ),
      ),
    );
  }
}
