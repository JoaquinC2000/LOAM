import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../game/effects_game.dart';

import '../models/app_state.dart';
import '../models/catalog.dart';
import '../models/minesweeper.dart';
import '../services/sound_service.dart';
import '../widgets/ad_dialog.dart';
import '../widgets/audio_menu.dart';
import '../widgets/board_view.dart';
import '../widgets/confetti.dart';
import '../widgets/game_header.dart';
import 'shop_screen.dart';

/// Estados posibles de una partida.
enum GameStatus { ready, playing, paused, won, lost }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late MinesweeperBoard board;
  GameStatus status = GameStatus.ready;
  Timer? _timer;

  /// En modo normal cuenta hacia arriba; en contrarreloj, los segundos que quedan.
  int seconds = 0;
  int winBonus = 0;
  bool flagMode = false;
  bool secondLifeUsed = false;
  bool showConfetti = false;

  /// true cuando el jugador activó la lupa y tiene que elegir una casilla.
  bool probeMode = false;

  /// Capa de efectos hecha con el motor Flame (partículas, explosión, fuegos artificiales).
  final EffectsGame effects = EffectsGame();

  Difficulty get difficulty => appState.difficulty;
  bool get isCountdown => appState.mode == GameMode.contrarreloj;
  int get score => board.revealedCount * difficulty.pointsPerCell + winBonus;
  bool get isPlaying => status == GameStatus.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    board = MinesweeperBoard(difficulty);
    seconds = isCountdown ? difficulty.timeLimit : 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// Si la app pasa a segundo plano (llamada, cambio de app), se pausa sola.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && isPlaying) _pause();
  }

  // ===================== Reloj =====================

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() => _timer?.cancel();

  void _tick() {
    setState(() => seconds += isCountdown ? -1 : 1);
    if (!isCountdown) return;
    if (seconds > 0 && seconds <= 10) {
      // Tic-tac de reloj en los últimos 10 segundos.
      SoundService.tick(seconds.isEven);
    } else if (seconds <= 0) {
      SoundService.timeUp();
      _onTimeUp();
    }
  }

  String get timeText {
    final s = min(max(seconds, 0), 5999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ===================== Botonera =====================

  void _start() {
    if (status != GameStatus.ready) return;
    setState(() => status = GameStatus.playing);
    _startTimer();
  }

  void _pause() {
    if (!isPlaying) return;
    _stopTimer();
    setState(() {
      status = GameStatus.paused;
      probeMode = false;
    });
  }

  void _resume() {
    if (status != GameStatus.paused) return;
    setState(() => status = GameStatus.playing);
    _startTimer();
  }

  /// Reiniciar: el mismo tablero, desde cero.
  Future<void> _restart() async {
    _stopTimer();
    await _maybeShowAd();
    if (!mounted) return;
    setState(() {
      board.restartSameBoard();
      _resetCounters();
    });
  }

  /// Nueva partida: tablero nuevo.
  Future<void> _newGame() async {
    _stopTimer();
    await _maybeShowAd();
    if (!mounted) return;
    setState(() {
      board = MinesweeperBoard(difficulty);
      _resetCounters();
    });
  }

  void _resetCounters() {
    status = GameStatus.ready;
    seconds = isCountdown ? difficulty.timeLimit : 0;
    winBonus = 0;
    flagMode = false;
    secondLifeUsed = false;
    showConfetti = false;
    probeMode = false;
  }

  /// La publicidad aparece al reiniciar o empezar otra partida (salvo cuentas PRO).
  Future<void> _maybeShowAd() async {
    if (appState.isPro) return;
    await showAdDialog(context);
  }

  Future<void> _exit() async {
    if (status == GameStatus.playing || status == GameStatus.paused) {
      final wasPlaying = isPlaying;
      _pause();
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Salir de la partida?'),
          content: const Text('Vas a perder el progreso de esta partida.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir jugando')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
          ],
        ),
      );
      if (leave != true) {
        if (wasPlaying) _resume();
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openShop() async {
    _pause();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
    if (mounted) setState(() {}); // por si cambió el tema o los íconos
  }

  // ===================== Jugadas =====================

  void _onCellTap(int row, int col) {
    if (status == GameStatus.ready) _start();
    if (!isPlaying) return;

    if (probeMode) {
      _applyProbe(row, col);
      return;
    }

    if (flagMode) {
      _toggleFlag(row, col);
      return;
    }

    late RevealResult result;
    setState(() {
      result = board.reveal(row, col);
    });
    if (result == RevealResult.mine) {
      SoundService.explosion();
      effects.explode(row, col);
      _onMineHit();
    } else if (result == RevealResult.safe) {
      SoundService.dig();
      effects.dig(row, col, appState.boardTheme.covered);
      if (board.isWon) _onWin();
    }
  }

  void _onCellLongPress(int row, int col) {
    if (status == GameStatus.ready) _start();
    if (!isPlaying) return;
    _toggleFlag(row, col);
  }

  /// Pone o saca una bandera, con sonido solo si realmente cambió.
  void _toggleFlag(int row, int col) {
    final before = board.flagsPlaced;
    setState(() => board.toggleFlag(row, col));
    if (board.flagsPlaced != before) SoundService.flag();
  }

  Future<void> _onMineHit() async {
    _stopTimer();
    // Pausa corta para que se vea la explosión de Flame antes del cartel.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final life = Catalog.secondLife;
    if (!secondLifeUsed && appState.diamonds >= life.cost) {
      final useLife = await _offerPowerDialog(
        emoji: '💥',
        title: '¡Boom!',
        message: '¿Usás una ${life.name} por ${life.cost} 💎 y seguís jugando?',
        cost: life.cost,
      );
      if (useLife && appState.spendDiamonds(life.cost)) {
        SoundService.power();
        setState(() {
          board.undoExplosion();
          secondLifeUsed = true;
          status = GameStatus.playing;
        });
        _startTimer();
        return;
      }
    }
    _onLose('¡Pisaste una mina!');
  }

  Future<void> _onTimeUp() async {
    _stopTimer();
    final extra = Catalog.extraTime;
    if (appState.diamonds >= extra.cost) {
      final buy = await _offerPowerDialog(
        emoji: '⌛',
        title: '¡Se acabó el tiempo!',
        message: '¿Comprás 30 segundos más por ${extra.cost} 💎?',
        cost: extra.cost,
      );
      if (buy && appState.spendDiamonds(extra.cost)) {
        SoundService.power();
        setState(() {
          seconds = 30;
          status = GameStatus.playing;
        });
        _startTimer();
        return;
      }
    }
    _onLose('¡Se acabó el tiempo!');
  }

  Future<void> _onLose(String reason) async {
    setState(() {
      board.isLost = true;
      board.revealAllMines();
      status = GameStatus.lost;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    SoundService.lose();
    _showResultDialog(won: false, reason: reason, diamondsWon: 0);
  }

  Future<void> _onWin() async {
    _stopTimer();
    final par = difficulty.timeLimit;
    final timeBonus = isCountdown ? seconds * difficulty.pointsPerCell * 2 : max(0, par - seconds) * difficulty.pointsPerCell;
    setState(() {
      winBonus = difficulty.winBonus + timeBonus;
      status = GameStatus.won;
      showConfetti = true;
    });
    effects.fireworks();
    SoundService.win();
    final isRecord = score > appState.bestScoreCurrent;
    final reward = appState.registerWin(score);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _showResultDialog(won: true, reason: isRecord ? '¡Nuevo récord! 🏆' : '¡Encontraste todas las minas!', diamondsWon: reward);
  }

  // ===================== Poderes =====================

  /// Activa o desactiva la lupa. Todavía no cobra: cobra al elegir la casilla.
  void _toggleProbe() {
    final probe = Catalog.probe;
    if (probeMode) {
      setState(() => probeMode = false);
      return;
    }
    if (!isPlaying) {
      _snack(status == GameStatus.ready ? 'Primero tocá INICIAR' : 'El juego no está en curso');
      return;
    }
    if (!board.minesPlaced) {
      _snack('Primero destapá una casilla');
      return;
    }
    if (appState.diamonds < probe.cost) {
      _snack('Te faltan diamantes 💎');
      _openShop();
      return;
    }
    setState(() => probeMode = true);
  }

  /// Usa la lupa sobre la casilla elegida.
  void _applyProbe(int row, int col) {
    final probe = Catalog.probe;
    late ProbeResult result;
    setState(() {
      result = board.probe(row, col);
    });
    if (result == ProbeResult.invalid) {
      _snack('Elegí una casilla tapada y sin bandera');
      return;
    }
    appState.spendDiamonds(probe.cost);
    SoundService.power();
    setState(() => probeMode = false);
    if (result == ProbeResult.mine) {
      _snack('🔍 ¡Ahí había una mina! Le pusimos ${appState.flagEmoji} (-${probe.cost} 💎)');
    } else {
      effects.dig(row, col, appState.boardTheme.covered);
      _snack('🔍 Casilla segura (-${probe.cost} 💎)');
      if (board.isWon) _onWin();
    }
  }

  void _usePower(PowerUp power, bool Function() effect) {
    if (!isPlaying) {
      _snack(status == GameStatus.ready ? 'Primero tocá INICIAR' : 'El juego no está en curso');
      return;
    }
    if (!board.minesPlaced) {
      _snack('Primero destapá una casilla');
      return;
    }
    if (appState.diamonds < power.cost) {
      _snack('Te faltan diamantes 💎');
      _openShop();
      return;
    }
    late bool ok;
    setState(() {
      ok = effect();
    });
    if (!ok) {
      _snack('No se puede usar ahora');
      return;
    }
    appState.spendDiamonds(power.cost);
    SoundService.power();
    _snack('${power.emoji} ${power.name}: -${power.cost} 💎');
    if (board.isWon) _onWin();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1400)));
  }

  // ===================== Diálogos =====================

  Future<bool> _offerPowerDialog({
    required String emoji,
    required String title,
    required String message,
    required int cost,
  }) async {
    // Si no decide en 10 segundos, el diálogo se cierra solo (devuelve false)
    // y se pasa al resumen de la partida.
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ContinueDialog(emoji: emoji, title: title, message: message, cost: cost),
    );
    return result ?? false;
  }

  void _showResultDialog({required bool won, required String reason, required int diamondsWon}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Text(won ? '🎉' : appState.mineEmoji, style: const TextStyle(fontSize: 56)),
        title: Text(won ? '¡Ganaste!' : '¡Perdiste!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _ResultRow(label: 'Puntos', value: '⭐ $score'),
            _ResultRow(label: 'Tiempo', value: '⏱️ $timeText'),
            if (won) _ResultRow(label: 'Premio', value: '💎 +$diamondsWon${appState.isPro ? ' (x2 PRO)' : ''}'),
            _ResultRow(label: 'Récord', value: '🏆 ${appState.bestScoreCurrent}'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('Menú'),
          ),
          if (!won)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _restart();
              },
              child: const Text('Reintentar'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            child: const Text('Nueva partida'),
          ),
        ],
      ),
    );
  }

  // ===================== Interfaz =====================

  @override
  Widget build(BuildContext context) {
    final theme = appState.boardTheme;
    effects.configureBoard(board.cols, board.rows);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                ListenableBuilder(
                  listenable: appState,
                  builder: (context, _) => GameHeader(
                    onBack: _exit,
                    onDiamondsTap: _openShop,
                    actions: const [AudioMenuButton()],
                    stats: [
                      HeaderStat(emoji: '⭐', label: 'Puntos', value: '$score'),
                      HeaderStat(
                        emoji: isCountdown ? '⏳' : '⏱️',
                        label: isCountdown ? 'Quedan' : 'Tiempo',
                        value: timeText,
                        warning: isCountdown && seconds <= 10 && isPlaying,
                      ),
                      HeaderStat(emoji: appState.flagEmoji, label: 'Banderas', value: '${board.flagsLeft}'),
                    ],
                  ),
                ),
                _buildToolsBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: Stack(
                      // Clip.none deja que el aviso de la lupa flote un poco por encima.
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: BoardView(
                            board: board,
                            theme: theme,
                            mineEmoji: appState.mineEmoji,
                            flagEmoji: appState.flagEmoji,
                            onCellTap: _onCellTap,
                            onCellLongPress: _onCellLongPress,
                          ),
                        ),
                        // Motor de juego Flame: capa transparente encima del tablero.
                        // IgnorePointer deja pasar los toques al tablero de abajo.
                        Positioned.fill(child: IgnorePointer(child: GameWidget(game: effects))),
                        if (status == GameStatus.ready || status == GameStatus.paused) Positioned.fill(child: _buildOverlay()),
                        // Aviso de la lupa: flota ENCIMA, así el tablero no se mueve.
                        Positioned(
                          top: -8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(scale: anim, child: child),
                              ),
                              child: probeMode ? _buildProbeBanner() : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildControls(),
              ],
            ),
            if (showConfetti) const Positioned.fill(child: Confetti()),
          ],
        ),
      ),
    );
  }

  /// Barra de herramientas: modo cavar/bandera y poderes.
  Widget _buildToolsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          // Interruptor Cavar / Bandera
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                _ModeChip(emoji: '⛏️', selected: !flagMode, onTap: () => setState(() => flagMode = false)),
                _ModeChip(emoji: appState.flagEmoji, selected: flagMode, onTap: () => setState(() => flagMode = true)),
              ],
            ),
          ),
          const Spacer(),
          _PowerButton(power: Catalog.probe, active: probeMode, onTap: _toggleProbe),
          const SizedBox(width: 6),
          _PowerButton(power: Catalog.radar, onTap: () => _usePower(Catalog.radar, board.useRadar)),
          if (isCountdown) ...[
            const SizedBox(width: 6),
            _PowerButton(
              power: Catalog.extraTime,
              onTap: () => _usePower(Catalog.extraTime, () {
                seconds += 30;
                return true;
              }),
            ),
          ],
        ],
      ),
    );
  }

  /// Cartelito compacto de la lupa (con botón ✕ para cancelar).
  Widget _buildProbeBanner() {
    return Material(
      key: const ValueKey('probe-banner'),
      color: const Color(0xFFFFF59D),
      elevation: 4,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFFBC02D), width: 2)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            const Text(
              'Tocá una casilla para revisarla',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF5D4037)),
            ),
            const SizedBox(width: 4),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => probeMode = false),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF5D4037)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cartel encima del tablero cuando está listo para empezar o en pausa.
  /// En pausa tapa el tablero para que no se pueda pensar sin que corra el tiempo.
  Widget _buildOverlay() {
    final paused = status == GameStatus.paused;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: paused ? appState.boardTheme.background.withValues(alpha: 0.96) : Colors.black.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(paused ? '⏸️' : '👆', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              paused ? 'Pausa' : '¿Listo?',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              paused ? 'El tiempo está detenido' : '${difficulty.label} · ${appState.mode.label} · ${difficulty.mines} minas',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF2E7D32)),
              onPressed: () {
                SoundService.tap();
                if (paused) {
                  _resume();
                } else {
                  _start();
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(paused ? 'CONTINUAR' : 'INICIAR'),
            ),
          ],
        ),
      ),
    );
  }

  /// Botonera de control, fuera del área de juego.
  Widget _buildControls() {
    final IconData mainIcon;
    final String mainLabel;
    final VoidCallback? mainAction;
    switch (status) {
      case GameStatus.ready:
        mainIcon = Icons.play_arrow_rounded;
        mainLabel = 'Iniciar';
        mainAction = _start;
      case GameStatus.playing:
        mainIcon = Icons.pause_rounded;
        mainLabel = 'Pausa';
        mainAction = _pause;
      case GameStatus.paused:
        mainIcon = Icons.play_arrow_rounded;
        mainLabel = 'Seguir';
        mainAction = _resume;
      case GameStatus.won:
      case GameStatus.lost:
        mainIcon = Icons.play_arrow_rounded;
        mainLabel = 'Iniciar';
        mainAction = null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Row(
          children: [
            Expanded(child: _ControlButton(icon: mainIcon, label: mainLabel, color: const Color(0xFF43A047), onTap: mainAction)),
            const SizedBox(width: 8),
            Expanded(child: _ControlButton(icon: Icons.replay_rounded, label: 'Reiniciar', color: const Color(0xFFFFA726), onTap: _restart)),
            const SizedBox(width: 8),
            Expanded(child: _ControlButton(icon: Icons.add_rounded, label: 'Nueva', color: const Color(0xFF42A5F5), onTap: _newGame)),
            const SizedBox(width: 8),
            Expanded(child: _ControlButton(icon: Icons.home_rounded, label: 'Menú', color: const Color(0xFFAB47BC), onTap: _exit)),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? color : color.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
      elevation: enabled ? 3 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap == null
            ? null
            : () {
                SoundService.tap();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.emoji, required this.selected, required this.onTap});

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundService.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF43A047) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.power, required this.onTap, this.active = false});

  final PowerUp power;
  final VoidCallback onTap;

  /// Resaltado cuando el poder está activado (ej: la lupa esperando una casilla).
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${power.name}: ${power.description}',
      child: Material(
        color: active ? const Color(0xFFFFF59D) : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: active ? const Color(0xFFFBC02D) : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            SoundService.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                Text(power.emoji, style: const TextStyle(fontSize: 20)),
                Text(
                  '${power.cost}💎',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1565C0)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// Diálogo de "¿Seguir jugando?" con cuenta regresiva de 10 segundos.
/// Si se termina el tiempo sin decidir, se cierra solo como si dijera "No".
class _ContinueDialog extends StatefulWidget {
  const _ContinueDialog({required this.emoji, required this.title, required this.message, required this.cost});

  final String emoji;
  final String title;
  final String message;
  final int cost;

  static const seconds = 10;

  @override
  State<_ContinueDialog> createState() => _ContinueDialogState();
}

class _ContinueDialogState extends State<_ContinueDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _ContinueDialog.seconds),
  );

  int _lastSecond = _ContinueDialog.seconds;

  /// Suena un "bip" en cada uno de los últimos 3 segundos.
  void _onCountdownTick() {
    final left = (_countdown.value * _ContinueDialog.seconds).ceil();
    if (left == _lastSecond) return;
    _lastSecond = left;
    if (left > 0 && left <= 3) SoundService.beep();
  }

  @override
  void initState() {
    super.initState();
    _countdown.addListener(_onCountdownTick);
    // Va de 1 a 0; al llegar a 0 se cierra el diálogo.
    _countdown.reverse(from: 1).whenComplete(() {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  void _answer(bool value) {
    SoundService.tap();
    _countdown.stop();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Column(
          children: [
            // Reloj circular que se va vaciando
            AnimatedBuilder(
              animation: _countdown,
              builder: (context, _) {
                final left = (_countdown.value * _ContinueDialog.seconds).ceil();
                final urgent = left <= 3;
                return SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _countdown.value,
                          strokeWidth: 7,
                          backgroundColor: Colors.black12,
                          color: urgent ? const Color(0xFFE53935) : const Color(0xFF43A047),
                        ),
                      ),
                      Text(
                        '$left',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: urgent ? const Color(0xFFE53935) : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text('${widget.emoji} ${widget.title}', textAlign: TextAlign.center),
          ],
        ),
        content: Text('${widget.message}\nTenés ${appState.diamonds} 💎', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => _answer(false), child: const Text('No, gracias')),
          FilledButton(onPressed: () => _answer(true), child: Text('Sí, seguir (${widget.cost} 💎)')),
        ],
      ),
    );
  }
}
