class MarioKartCup {
  final String id;
  final String name;
  final String category; // 'Hauptspiel' oder 'Booster-Streckenpass'
  final List<String> tracks;

  const MarioKartCup({
    required this.id,
    required this.name,
    required this.category,
    required this.tracks,
  });
}

class MarioKartData {
  /// Offizielle Punkteverteilung nach Platzierung in Mario Kart 8 Deluxe
  static const Map<int, int> placementPoints = {
    1: 15,
    2: 12,
    3: 10,
    4: 9,
    5: 8,
    6: 7,
    7: 6,
    8: 5,
    9: 4,
    10: 3,
    11: 2,
    12: 1,
  };

  /// Liefert die Punkte für eine Platzierung
  static int getPointsForPlacement(int placement) {
    if (placement <= 0) return 0;
    return placementPoints[placement] ?? (placement <= 12 ? 1 : 0);
  }

  /// Liefert den Handicap-Multiplikator basierend auf dem Rang in der All-Time Multiplikator-Statistik
  /// 1. Platz: 1.0
  /// 2. Platz: 1.1
  /// 3. Platz: 1.22
  /// 4. Platz: 1.36
  /// ab 5. Platz: Fortführung mit +0.16, +0.18, +0.20 usw.
  static double getMultiplierForRank(int rank) {
    if (rank <= 1) return 1.0;
    if (rank == 2) return 1.1;
    if (rank == 3) return 1.22;
    if (rank == 4) return 1.36;

    double m = 1.36;
    double step = 0.16;
    for (int r = 5; r <= rank; r++) {
      m += step;
      step += 0.02;
    }
    return double.parse(m.toStringAsFixed(2));
  }

  /// Alle 24 Grand Prix Cups von Mario Kart 8 Deluxe mit ihren 4 Strecken
  static const List<MarioKartCup> allCups = [
    // --- HAUPTSPIEL: RETRO- & NITROCUP (12 Cups) ---
    MarioKartCup(
      id: 'mushroom',
      name: 'Pilz-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Mario Kart-Stadion',
        'Wasserpark',
        'Zuckersüßer Canyon',
        'Steinblock-Ruinen',
      ],
    ),
    MarioKartCup(
      id: 'flower',
      name: 'Blumen-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Mario-Piste',
        'Toads Hafenstadt',
        'Poltergipfel',
        'Shy Guy-Wasserfälle',
      ],
    ),
    MarioKartCup(
      id: 'star',
      name: 'Stern-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Sonnenflughafen',
        'Delfinlagune',
        'Diskodrom',
        'Wario-Abfahrt',
      ],
    ),
    MarioKartCup(
      id: 'special',
      name: 'Spezial-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Wolkenstraße',
        'Knochentrockene Dünen',
        'Bowsers Festung',
        'Regenbogen-Boulevard',
      ],
    ),
    MarioKartCup(
      id: 'shell',
      name: 'Panzer-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Kuhmuh-Weide (Wii)',
        'Mario-Piste (GBA)',
        'Cheep Cheep-Strand (DS)',
        'Toads Autobahn (N64)',
      ],
    ),
    MarioKartCup(
      id: 'banana',
      name: 'Bananen-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Staubtrockene Wüste (GCN)',
        'Donut-Ebene 3 (SNES)',
        'Königliche Rennpiste (N64)',
        'DK Dschungel (3DS)',
      ],
    ),
    MarioKartCup(
      id: 'leaf',
      name: 'Blatt-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Wario-Arena (DS)',
        'Scherben-Scherbengericht (GCN)',
        'Musikpark (3DS)',
        'Yoshi-Tal (N64)',
      ],
    ),
    MarioKartCup(
      id: 'lightning',
      name: 'Blitz-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Ticktack-Trauma (DS)',
        'Piranha-Pflanzen-Rutsche (3DS)',
        'Vulkangrollen (Wii)',
        'Regenbogen-Boulevard (N64)',
      ],
    ),
    MarioKartCup(
      id: 'egg',
      name: 'Ei-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Yoshi-Piste (GCN)',
        'Excitebike-Arena',
        'Große Drachenmauer',
        'Mute City',
      ],
    ),
    MarioKartCup(
      id: 'triforce',
      name: 'Triforce-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Warios Goldmine (Wii)',
        'Regenbogen-Boulevard (SNES)',
        'Polarkreis-Parcours',
        'Hyrule-Piste',
      ],
    ),
    MarioKartCup(
      id: 'crossing',
      name: 'Crossing-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Baby-Park (GCN)',
        'Käse-Land (GBA)',
        'Wilder Wald',
        'Animal Crossing',
      ],
    ),
    MarioKartCup(
      id: 'bell',
      name: 'Glocken-Cup',
      category: 'Hauptspiel',
      tracks: [
        'Koopa-Großstadtfieber (3DS)',
        'Party-Straße (GBA)',
        'Schlingerland',
        'Big Blue',
      ],
    ),

    // --- BOOSTER-STRECKENPASS (12 Cups) ---
    MarioKartCup(
      id: 'golden_dash',
      name: 'Goldener Turbo-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Paris-Parcours (Tour)',
        'Toads Piste (3DS)',
        'Schoko-Sumpf (N64)',
        'Kokos-Promenade (Wii)',
      ],
    ),
    MarioKartCup(
      id: 'lucky_cat',
      name: 'Glückskatzen-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Tokio-Tempotour (Tour)',
        'Pilz-Pass (DS)',
        'Wolkenpiste (GBA)',
        'Ninja-Dojo',
      ],
    ),
    MarioKartCup(
      id: 'turnip',
      name: 'Rüben-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'New-York-Spurt (Tour)',
        'Mario-Piste 3 (SNES)',
        'Kalimari-Wüste (N64)',
        'Waluigi-Flipper (DS)',
      ],
    ),
    MarioKartCup(
      id: 'propeller',
      name: 'Propeller-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Sydney-Spritztour (Tour)',
        'Schneeland (GBA)',
        'Pilz-Schlucht (Wii)',
        'Eiscreme-Eskapade',
      ],
    ),
    MarioKartCup(
      id: 'rock',
      name: 'Fels-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'London-Tour (Tour)',
        'Buu-Huu-Tal (GBA)',
        'Gebirgspfad (3DS)',
        'Blätterwald (Wii)',
      ],
    ),
    MarioKartCup(
      id: 'moon',
      name: 'Mond-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Pflaster von Berlin (Tour)',
        'Peachs Schlossgarten (DS)',
        'Bergbescherung',
        'Regenbogen-Boulevard (3DS)',
      ],
    ),
    MarioKartCup(
      id: 'fruit',
      name: 'Frucht-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Ausfahrt Amsterdam (Tour)',
        'Flussufer-Park (GBA)',
        'DK Skikane (Wii)',
        'Yoshi-Insel',
      ],
    ),
    MarioKartCup(
      id: 'boomerang',
      name: 'Bumerang-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Bangkok-Abendrot (Tour)',
        'Mario-Piste (DS)',
        'Waluigi-Arena (GCN)',
        'Überholspur Singapur (Tour)',
      ],
    ),
    MarioKartCup(
      id: 'feather',
      name: 'Feder-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Athen auf Abwegen (Tour)',
        'Daisys Dampfer (GCN)',
        'Mondblickstraße (Wii)',
        'Bad-Parcours',
      ],
    ),
    MarioKartCup(
      id: 'cherry',
      name: 'Doppelkirschen-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Los-Angeles-Strandspaziergang (Tour)',
        'Sonnenuntergangs-Wüste (GBA)',
        'Koopa-Kap (Wii)',
        'Vancouver-Wildnis (Tour)',
      ],
    ),
    MarioKartCup(
      id: 'acorn',
      name: 'Eichel-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Rom-Rambazamba (Tour)',
        'DK Bergland (GCN)',
        'Daisys Piste (Wii)',
        'Piranha-Pflanzen-Bucht',
      ],
    ),
    MarioKartCup(
      id: 'spiny',
      name: 'Stachi-Cup',
      category: 'Booster-Streckenpass',
      tracks: [
        'Madrid-Drive (Tour)',
        'Rosalinas Eisplanet (3DS)',
        'Bowsers Festung 3 (SNES)',
        'Regenbogen-Boulevard (Wii)',
      ],
    ),
  ];

  static MarioKartCup findCupById(String id) {
    return allCups.firstWhere(
      (cup) => cup.id == id,
      orElse: () => allCups.first,
    );
  }
}

