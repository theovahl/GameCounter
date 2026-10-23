import 'package:flutter/material.dart';
import 'olympiade_editions.dart';
import 'olympiade_disciplines.dart';
import 'olympiade_info_widgets.dart';
import 'olympiade_setup_screen.dart';

/// Einstieg der WG Olympiade: Auswahl der Ausgabe
class OlympiadeEditionsScreen extends StatelessWidget {
  const OlympiadeEditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WG Olympiade'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ausgabe auswählen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...olympiadeEditions.map((edition) => _buildEditionCard(context, edition)),
        ],
      ),
    );
  }

  Widget _buildEditionCard(BuildContext context, OlympiadeEdition edition) {
    final bool isLatest = edition == olympiadeEditions.first;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: isLatest
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.amber.withValues(alpha: 0.3), const Color(0xFF1E1E1E)],
                )
              : null,
          border: Border.all(
            color: isLatest ? Colors.amberAccent : Colors.grey.shade800,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OlympiadeEditionScreen(edition: edition)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 40,
                      color: isLatest ? Colors.amberAccent : Colors.grey,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            edition.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${edition.number}. Ausgabe',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'AKTUELL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Disziplinen der Ausgabe als Icons
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: edition.disciplines.map((d) {
                    final info = olympiadeDiscipline(d);
                    return Tooltip(
                      message: edition.rulesFor(d)?.title ?? info.name,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: info.color.withValues(alpha: 0.18),
                        child: Icon(info.icon, size: 17, color: info.color),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  '${edition.disciplines.length} Disziplinen • ${edition.schedule.map((d) => d.name).join(' – ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Eine Ausgabe: Wettkampf (Olympiaden), Regeln und Zeitplan
class OlympiadeEditionScreen extends StatelessWidget {
  final OlympiadeEdition edition;

  const OlympiadeEditionScreen({super.key, required this.edition});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(edition.title),
              Text(
                '${edition.number}. Ausgabe',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            tabs: [
              Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Wettkampf'),
              Tab(icon: Icon(Icons.menu_book), text: 'Regeln'),
              Tab(icon: Icon(Icons.schedule), text: 'Zeitplan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OlympiadeSetupScreen(edition: edition),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [OlympiadeRulesList(edition: edition)],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [OlympiadeScheduleList(edition: edition)],
            ),
          ],
        ),
      ),
    );
  }
}
