import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_counter/auth_service.dart';
import 'package:game_counter/friends_screen.dart';
import 'olympiade_models.dart';
import 'olympiade_service.dart';
import 'olympiade_disciplines.dart';
import 'olympiade_editions.dart';
import 'olympiade_screen.dart';

/// Wettkampf-Bereich einer Ausgabe: deren Olympiaden und neue Olympiade anlegen.
/// Wird als Reiter in [OlympiadeEditionScreen] angezeigt.
class OlympiadeSetupScreen extends StatefulWidget {
  final OlympiadeEdition edition;

  const OlympiadeSetupScreen({super.key, required this.edition});

  @override
  State<OlympiadeSetupScreen> createState() => _OlympiadeSetupScreenState();
}

enum _SetupTab { list, newOlympiade }

class _OlympiadeSetupScreenState extends State<OlympiadeSetupScreen> {
  final AuthService _authService = AuthService();
  final OlympiadeService _service = OlympiadeService();

  final List<TextEditingController> _nameControllers = [
    TextEditingController(text: 'Unsere WG'),
    TextEditingController(text: 'Gegner-WG'),
  ];

  _SetupTab _selectedTab = _SetupTab.list;

  // Mitglieder-UIDs pro WG
  final List<List<String>> _wgUids = [[], []];
  bool _initializedMe = false;

  late final Set<String> _disciplines = widget.edition.disciplines.toSet();

  // Disziplinen in der Reihenfolge der Ausgabe, danach alle übrigen
  List<String> get _disciplineOrder => [
        ...widget.edition.disciplines,
        ...olympiadeAllDisciplines.where((d) => !widget.edition.disciplines.contains(d)),
      ];

  bool _isStarting = false;

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _startOlympiade({
    required String myUid,
    required Map<String, String> playerNames,
  }) async {
    final names = _nameControllers.map((c) => c.text.trim()).toList();
    for (int i = 0; i < 2; i++) {
      if (names[i].isEmpty) names[i] = 'WG ${i + 1}';
      if (_wgUids[i].isEmpty) {
        _showError('${names[i]} hat noch keine Mitglieder.');
        return;
      }
    }
    if (_disciplines.isEmpty) {
      _showError('Wähle mindestens eine Disziplin aus.');
      return;
    }

    setState(() => _isStarting = true);

    try {
      final wgs = List.generate(2, (i) {
        return OlympiadeWg(
          name: names[i],
          playerUids: List<String>.from(_wgUids[i]),
          playerNames: _wgUids[i].map((uid) => playerNames[uid] ?? 'Mitspieler').toList(),
        );
      });

      final olympiade = await _service.createOlympiade(
        editionId: widget.edition.id,
        createdBy: myUid,
        wgs: wgs,
        disciplines: _disciplineOrder.where(_disciplines.contains).toList(),
      );

      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _selectedTab = _SetupTab.list;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OlympiadeScreen(olympiade: olympiade)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      _showError('Fehler beim Starten: $e');
    }
  }

  void _showAddMemberSheet(int wgIndex, Map<String, String> playerNames, String myUid) {
    final color = olympiadeWgColors[wgIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = playerNames.entries
                .where((e) => !_wgUids[0].contains(e.key) && !_wgUids[1].contains(e.key))
                .toList();
            final wgName = _nameControllers[wgIndex].text.trim().isEmpty
                ? 'WG ${wgIndex + 1}'
                : _nameControllers[wgIndex].text.trim();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mitglied zu $wgName hinzufügen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'Alle Freunde sind bereits einer WG zugeordnet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: available.map((entry) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.25),
                              child: Icon(Icons.person, color: color, size: 20),
                            ),
                            title: Text(entry.key == myUid ? '${entry.value} (Du)' : entry.value),
                            trailing: Icon(Icons.add_circle_outline, color: color),
                            onTap: () {
                              setState(() => _wgUids[wgIndex].add(entry.key));
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Fertig'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUserId;

    if (myUid == null) {
      return const Scaffold(
        body: Center(child: Text('Bitte melde dich zuerst an.')),
      );
    }

    if (!_initializedMe) {
      _wgUids[0].add(myUid);
      _initializedMe = true;
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _authService.currentUserStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final myData = userSnapshot.data?.data() ?? {};
        final String myUsername = myData['username'] ?? 'Ich';
        final List<String> friendUids = List<String>.from(myData['friends'] ?? []);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _authService.getUsersByIds(friendUids),
          builder: (context, friendsSnapshot) {
            final friends = friendsSnapshot.data ?? [];
            final bool isLoadingFriends =
                friendsSnapshot.connectionState == ConnectionState.waiting;

            // Alle verfügbaren Personen: du + deine Freunde
            final playerNames = <String, String>{
              myUid: myUsername,
              for (final f in friends)
                if (f['uid'] is String) f['uid'] as String: f['username'] ?? 'Unbekannt',
            };

            return Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<_SetupTab>(
                      segments: const [
                        ButtonSegment(
                          value: _SetupTab.list,
                          label: Text('Olympiaden'),
                          icon: Icon(Icons.emoji_events_outlined),
                        ),
                        ButtonSegment(
                          value: _SetupTab.newOlympiade,
                          label: Text('Neue Olympiade'),
                          icon: Icon(Icons.add),
                        ),
                      ],
                      selected: {_selectedTab},
                      onSelectionChanged: (Set<_SetupTab> newSelection) {
                        setState(() {
                          _selectedTab = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _selectedTab == _SetupTab.list
                          ? _buildOlympiadenList(myUid)
                          : (isLoadingFriends
                              ? const Center(child: CircularProgressIndicator())
                              : _buildNewOlympiadeForm(
                                  myUid: myUid,
                                  playerNames: playerNames,
                                  hasFriends: friends.isNotEmpty,
                                )),
                    ),
                    if (_selectedTab == _SetupTab.newOlympiade && !isLoadingFriends) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isStarting
                            ? null
                            : () => _startOlympiade(myUid: myUid, playerNames: playerNames),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black,
                        ),
                        icon: _isStarting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.emoji_events),
                        label: const Text(
                          'Olympiade starten',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(OlympiadeGame olympiade) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Olympiade löschen?'),
        content: const Text(
          'Die Olympiade wird mit allen Ergebnissen und den darin gespielten Spielen gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && olympiade.id != null) {
      await _service.deleteOlympiade(olympiade.id!);
    }
  }

  // --- TAB 1: Alle Olympiaden ---
  Widget _buildOlympiadenList(String myUid) {
    return StreamBuilder<List<OlympiadeGame>>(
      stream: _service.getUserOlympiadenStream(myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = (snapshot.data ?? [])
            // Über die aufgelöste Ausgabe filtern: unbekannte Kennungen zählen zur Standard-Ausgabe
            .where((o) => o.edition.id == widget.edition.id)
            .toList();
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Noch keine Olympiade in dieser Ausgabe.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = _SetupTab.newOlympiade);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Jetzt die erste Olympiade starten'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final olympiade = list[index];
            final bool isActive = olympiade.status == 'active' && !olympiade.allDone;
            final points = olympiade.points;
            final leader = olympiadeLeader(points);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.amber.shade700 : Colors.grey.shade800,
                  child: Icon(Icons.emoji_events, color: isActive ? Colors.black : Colors.white, size: 20),
                ),
                title: Text(
                  olympiade.wgs.map((w) => w.name).join('  vs.  '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${points.map(formatOlympiadePoints).join(' : ')}  •  '
                      '${olympiade.doneCount}/${olympiade.disciplines.length} Disziplinen  •  '
                      '${olympiade.date.day}.${olympiade.date.month}.${olympiade.date.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? 'Läuft'
                          : (leader == olympiadeDraw
                              ? 'Unentschieden'
                              : '${olympiade.wgs[leader].name} hat gewonnen'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? Colors.amberAccent
                            : (leader == olympiadeDraw ? Colors.grey : olympiadeWgColors[leader]),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Löschen',
                  onPressed: () => _confirmDelete(olympiade),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OlympiadeScreen(olympiade: olympiade)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: Neue Olympiade ---
  Widget _buildNewOlympiadeForm({
    required String myUid,
    required Map<String, String> playerNames,
    required bool hasFriends,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...List.generate(2, (i) => _buildWgEditor(i, playerNames, myUid)),

          if (!hasFriends) ...[
            const SizedBox(height: 8),
            const Text(
              'Du hast noch keine Freunde in deiner Liste. Die Mitglieder beider WGs müssen deine Freunde sein.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 13),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendsScreen()),
                );
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Freunde hinzufügen'),
            ),
          ),
          const SizedBox(height: 12),

          // Disziplinen
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Disziplinen',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${_disciplines.length} ausgewählt',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Jede Disziplin wird einmal gespielt. Die Reihenfolge wählt ihr während der Olympiade.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _disciplineOrder.map((key) {
              final info = olympiadeDiscipline(key);
              final isSelected = _disciplines.contains(key);
              return FilterChip(
                avatar: Icon(info.icon, size: 18, color: isSelected ? info.color : Colors.grey),
                label: Text(info.name),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: info.color.withValues(alpha: 0.2),
                side: BorderSide(color: isSelected ? info.color : Colors.grey.shade700),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _disciplines.add(key);
                    } else {
                      _disciplines.remove(key);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWgEditor(int wgIndex, Map<String, String> playerNames, String myUid) {
    final color = olympiadeWgColors[wgIndex];
    final uids = _wgUids[wgIndex].where(playerNames.containsKey).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameControllers[wgIndex],
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
              decoration: InputDecoration(
                labelText: 'Name der WG',
                prefixIcon: Icon(Icons.home, color: color),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${uids.length} ${uids.length == 1 ? "Mitglied" : "Mitglieder"}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (uids.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: uids.map((uid) {
                  final name = playerNames[uid]!;
                  return Chip(
                    label: Text(uid == myUid ? '$name (Du)' : name),
                    side: BorderSide(color: color.withValues(alpha: 0.6)),
                    onDeleted: () => setState(() => _wgUids[wgIndex].remove(uid)),
                  );
                }).toList(),
              ),
            TextButton.icon(
              onPressed: () => _showAddMemberSheet(wgIndex, playerNames, myUid),
              icon: Icon(Icons.person_add_alt_1, color: color, size: 18),
              label: Text('Mitglied hinzufügen', style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
