import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'minesweeper.dart';

/// Estado global de la app: usuario, diamantes, cuenta, compras y ajustes.
///
/// Extiende ChangeNotifier: cuando algo cambia se llama a notifyListeners()
/// y todas las pantallas que lo escuchan (con ListenableBuilder) se redibujan.
/// Todo se guarda en el teléfono con shared_preferences, así funciona offline.
class AppState extends ChangeNotifier {
  // ---- Usuario (login simulado: ya entra logueado) ----
  String userName = 'Joaquín';
  String avatar = '🦊';

  // ---- Economía ----
  int diamonds = 100;
  bool isPro = false;

  // ---- Puntajes ----
  /// Récord por dificultad y modo, ej: 'facil_normal' -> 340
  final Map<String, int> bestScores = {};
  int gamesWon = 0;

  // ---- Ajustes ----
  ThemeMode themeMode = ThemeMode.light;
  bool soundOn = true;
  bool musicOn = true;
  Difficulty difficulty = Difficulty.facil;
  GameMode mode = GameMode.normal;

  // ---- Tienda ----
  Set<String> ownedThemes = {'pradera'};
  Set<String> ownedMines = {'bomba'};
  Set<String> ownedFlags = {'bandera'};
  String selectedTheme = 'pradera';
  String selectedMine = 'bomba';
  String selectedFlag = 'bandera';

  SharedPreferences? _prefs;

  BoardTheme get boardTheme => Catalog.themeById(selectedTheme);
  String get mineEmoji => Catalog.mineById(selectedMine).emoji;
  String get flagEmoji => Catalog.flagById(selectedFlag).emoji;
  bool get isDark => themeMode == ThemeMode.dark;
  String get accountLabel => isPro ? 'PRO' : 'BASIC';

  int bestScoreFor(Difficulty d, GameMode m) => bestScores['${d.name}_${m.name}'] ?? 0;
  int get bestScoreCurrent => bestScoreFor(difficulty, mode);

  // ================= Guardar y cargar =================

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    diamonds = p.getInt('diamonds') ?? 100;
    isPro = p.getBool('isPro') ?? false;
    gamesWon = p.getInt('gamesWon') ?? 0;
    themeMode = (p.getBool('dark') ?? false) ? ThemeMode.dark : ThemeMode.light;
    soundOn = p.getBool('soundOn') ?? true;
    musicOn = p.getBool('musicOn') ?? true;
    difficulty = Difficulty.values.byName(p.getString('difficulty') ?? 'facil');
    mode = GameMode.values.byName(p.getString('mode') ?? 'normal');
    ownedThemes = (p.getStringList('ownedThemes') ?? ['pradera']).toSet();
    ownedMines = (p.getStringList('ownedMines') ?? ['bomba']).toSet();
    ownedFlags = (p.getStringList('ownedFlags') ?? ['bandera']).toSet();
    selectedTheme = p.getString('selectedTheme') ?? 'pradera';
    selectedMine = p.getString('selectedMine') ?? 'bomba';
    selectedFlag = p.getString('selectedFlag') ?? 'bandera';
    for (final d in Difficulty.values) {
      for (final m in GameMode.values) {
        final key = '${d.name}_${m.name}';
        final value = p.getInt('best_$key');
        if (value != null) bestScores[key] = value;
      }
    }
    // Si dejó de ser PRO, no puede seguir usando el tema exclusivo.
    if (!isPro && boardTheme.proOnly) selectedTheme = 'pradera';
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('diamonds', diamonds);
    await p.setBool('isPro', isPro);
    await p.setInt('gamesWon', gamesWon);
    await p.setBool('dark', isDark);
    await p.setBool('soundOn', soundOn);
    await p.setBool('musicOn', musicOn);
    await p.setString('difficulty', difficulty.name);
    await p.setString('mode', mode.name);
    await p.setStringList('ownedThemes', ownedThemes.toList());
    await p.setStringList('ownedMines', ownedMines.toList());
    await p.setStringList('ownedFlags', ownedFlags.toList());
    await p.setString('selectedTheme', selectedTheme);
    await p.setString('selectedMine', selectedMine);
    await p.setString('selectedFlag', selectedFlag);
    for (final entry in bestScores.entries) {
      await p.setInt('best_${entry.key}', entry.value);
    }
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ================= Ajustes =================

  void toggleDarkMode() {
    themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    _changed();
  }

  void toggleSound() {
    soundOn = !soundOn;
    _changed();
  }

  void toggleMusic() {
    musicOn = !musicOn;
    _changed();
  }

  void setDifficulty(Difficulty d) {
    difficulty = d;
    _changed();
  }

  void setMode(GameMode m) {
    mode = m;
    _changed();
  }

  // ================= Diamantes =================

  void addDiamonds(int amount) {
    diamonds += amount;
    _changed();
  }

  /// Gasta diamantes. Devuelve false si no alcanzan.
  bool spendDiamonds(int amount) {
    if (diamonds < amount) return false;
    diamonds -= amount;
    _changed();
    return true;
  }

  /// Compra simulada de un paquete con dinero real.
  void buyDiamondPack(DiamondPack pack) => addDiamonds(pack.diamonds + pack.bonus);

  /// Suscripción PRO simulada.
  void activatePro() {
    isPro = true;
    diamonds += Catalog.proGiftDiamonds;
    ownedThemes.add('dorado');
    _changed();
  }

  void cancelPro() {
    isPro = false;
    if (boardTheme.proOnly) selectedTheme = 'pradera';
    _changed();
  }

  // ================= Tienda de objetos =================

  bool ownsTheme(BoardTheme t) => t.proOnly ? isPro : ownedThemes.contains(t.id);

  bool buyTheme(BoardTheme t) {
    if (!spendDiamonds(t.price)) return false;
    ownedThemes.add(t.id);
    selectedTheme = t.id;
    _changed();
    return true;
  }

  void selectTheme(BoardTheme t) {
    selectedTheme = t.id;
    _changed();
  }

  bool buyMine(SkinItem s) {
    if (!spendDiamonds(s.price)) return false;
    ownedMines.add(s.id);
    selectedMine = s.id;
    _changed();
    return true;
  }

  void selectMine(SkinItem s) {
    selectedMine = s.id;
    _changed();
  }

  bool buyFlag(SkinItem s) {
    if (!spendDiamonds(s.price)) return false;
    ownedFlags.add(s.id);
    selectedFlag = s.id;
    _changed();
    return true;
  }

  void selectFlag(SkinItem s) {
    selectedFlag = s.id;
    _changed();
  }

  // ================= Resultados =================

  /// Registra una partida ganada. Devuelve los diamantes ganados.
  int registerWin(int score) {
    gamesWon++;
    final key = '${difficulty.name}_${mode.name}';
    if (score > (bestScores[key] ?? 0)) bestScores[key] = score;
    final reward = difficulty.diamondReward * (isPro ? 2 : 1);
    diamonds += reward;
    _changed();
    return reward;
  }
}

/// Instancia única que usa toda la app.
final appState = AppState();
