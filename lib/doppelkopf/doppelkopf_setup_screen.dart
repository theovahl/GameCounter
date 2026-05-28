import 'package:flutter/material.dart';
import 'doppelkopf_game_model.dart';
import 'package:game_counter/database_helper.dart';
import 'doppelkopf_score_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<TextEditingController> _playerControllers = List.generate(4, (_) => TextEditingController());
  final TextEditingController _groupNameController = TextEditingController();

  List<PlayerGroup> _existingGroups = [];
  PlayerGroup? _selectedGroup;
  bool _isCreatingNewGroup = true;

  @override
  void initState() {
    super.initState();
    _loadGroups(); // Lädt beim Start alle gespeicherten Gruppen aus der DB
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper.instance.getAllGroups();
    setState(() {
      _existingGroups = groups;
      if (groups.isNotEmpty) {
        _selectedGroup = groups.first;
        _isCreatingNewGroup = false; // Wenn Gruppen da sind, zeigen wir erst die Auswahl
      }
    });
  }

  @override
  void dispose() {
    for (var c in _playerControllers) {
      c.dispose();
    }
    _groupNameController.dispose();
    super.dispose();
  }

  void _startGame() async {
    int groupId;
    List<String> names = [];

    if (_isCreatingNewGroup) {
      // 1. Neue Gruppe in DB speichern
      String groupName = _groupNameController.text.trim();
      if (groupName.isEmpty) groupName = "Runde am ${DateTime.now().day}.${DateTime.now().month}.";

      for (int i = 0; i < 4; i++) {
        String n = _playerControllers[i].text.trim();
        names.add(n.isEmpty ? 'Spieler ${i + 1}' : n);
      }

      final newGroup = PlayerGroup(name: groupName, players: names);
      groupId = await DatabaseHelper.instance.createGroup(newGroup);
    } else {
      // 2. Bestehende Gruppe nutzen
      groupId = _selectedGroup!.id!;
      names = _selectedGroup!.players;
    }

    // 3. Ein neues Spiel für diese Gruppe in der DB registrieren
    int gameId = await DatabaseHelper.instance.createGame(groupId);

    // 4. Das Spiel-Objekt für das UI bauen
    final game = DoppelkopfGame(id: gameId, groupId: groupId, date: DateTime.now(), players: names);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScoreScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spieler Setup'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Switcher zwischen "Gruppe wählen" und "Neue Gruppe"
            if (_existingGroups.isNotEmpty) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Gruppe wählen'), icon: Icon(Icons.group)),
                  ButtonSegment(value: true, label: Text('Neu anlegen'), icon: Icon(Icons.group_add)),
                ],
                selected: {_isCreatingNewGroup},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isCreatingNewGroup = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 20),
            ],

            Expanded(
              child: SingleChildScrollView(
                child: _isCreatingNewGroup 
                    ? _buildNewGroupForm() 
                    : _buildGroupDropdown(),
              ),
            ),

            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade700,
              ),
              child: const Text('Spiel starten', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Wähle eine deiner Gruppen:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        DropdownButtonFormField<PlayerGroup>(
          initialValue: _selectedGroup,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _existingGroups.map((group) {
            return DropdownMenuItem(
              value: group,
              child: Text('${group.name} (${group.players.join(", ")})'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedGroup = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNewGroupForm() {
    return Column(
      children: [
        TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            labelText: 'Name der Gruppe (z.B. Stammtisch)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Wer spielt mit?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: TextField(
              controller: _playerControllers[index],
              decoration: InputDecoration(
                labelText: 'Spieler ${index + 1}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
          );
        }),
      ],
    );
  }
}