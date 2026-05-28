import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'doppelkopf/doppelkopf_game_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('games_block.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabelle für Gruppen
    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        players TEXT NOT NULL
      )
    ''');

    // Tabelle für Spiele
    await db.execute('''
      CREATE TABLE games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        groupId INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Tabelle für Runden
    await db.execute('''
      CREATE TABLE rounds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gameId INTEGER NOT NULL,
        roundNumber INTEGER NOT NULL,
        scores TEXT NOT NULL
      )
    ''');
  }

  // --- HILFSFUNKTIONEN FÜR GRUPPEN ---

  // Gruppe speichern
  Future<int> createGroup(PlayerGroup group) async {
    final db = await instance.database;
    return await db.insert('groups', group.toMap());
  }

  // Alle Gruppen laden
  Future<List<PlayerGroup>> getAllGroups() async {
    final db = await instance.database;
    final result = await db.query('groups', orderBy: 'id DESC');
    return result.map((json) => PlayerGroup.fromMap(json)).toList();
  }

  // --- HILFSFUNKTIONEN FÜR SPIELE & RUNDEN ---

  Future<int> createGame(int groupId) async {
    final db = await instance.database;
    return await db.insert('games', {
      'groupId': groupId,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<int> createRound(GameRound round) async {
    final db = await instance.database;
    return await db.insert('rounds', round.toMap());
  }
}