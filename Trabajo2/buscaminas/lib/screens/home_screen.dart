import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/catalog.dart';
import '../models/minesweeper.dart';
import '../services/sound_service.dart';
import '../widgets/ad_dialog.dart';
import '../widgets/audio_menu.dart';
import '../widgets/game_header.dart';
import 'game_screen.dart';
import 'shop_screen.dart';

/// Pantalla de inicio: elegir dificultad y modo, ir a la tienda o jugar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _difficultyEmoji = {
    Difficulty.facil: '🐣',
    Difficulty.medio: '🦊',
    Difficulty.dificil: '🦁',
  };

  static const _difficultyColor = {
    Difficulty.facil: Color(0xFF66BB6A),
    Difficulty.medio: Color(0xFFFFA726),
    Difficulty.dificil: Color(0xFFEF5350),
  };

  void _openShop(BuildContext context, {int tab = 0}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(initialTab: tab)));
  }

  void _play(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  Future<void> _watchRewardedAd(BuildContext context) async {
    final watched = await showAdDialog(context, rewarded: true);
    if (!watched) return;
    appState.addDiamonds(Catalog.rewardedAdDiamonds);
    SoundService.coin();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Ganaste ${Catalog.rewardedAdDiamonds} 💎!')),
      );
    }
  }

  String _formatTime(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          body: Column(
            children: [
              GameHeader(
                onDiamondsTap: () => _openShop(context),
                actions: [
                  const AudioMenuButton(),
                  IconButton(
                    tooltip: appState.isDark ? 'Modo claro' : 'Modo oscuro',
                    onPressed: () {
                      SoundService.tap();
                      appState.toggleDarkMode();
                    },
                    icon: Icon(
                      appState.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
                stats: [
                  HeaderStat(emoji: '🏆', label: 'Récord', value: '${appState.bestScoreCurrent}'),
                  HeaderStat(emoji: '🎮', label: 'Ganadas', value: '${appState.gamesWon}'),
                  HeaderStat(
                    emoji: appState.mineEmoji,
                    label: 'Tema',
                    value: appState.boardTheme.name,
                    onTap: () => _openShop(context, tab: 1), // abre la tienda en Temas
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    // Sin const: se redibuja si cambiás los íconos en la tienda.
                    // ignore: prefer_const_constructors
                    _Logo(),
                    const SizedBox(height: 24),
                    _sectionTitle(context, 'Elegí la dificultad'),
                    Row(
                      children: [
                        for (final d in Difficulty.values) ...[
                          if (d != Difficulty.facil) const SizedBox(width: 10),
                          Expanded(
                            child: _OptionCard(
                              selected: appState.difficulty == d,
                              color: _difficultyColor[d]!,
                              emoji: _difficultyEmoji[d]!,
                              title: d.label,
                              subtitle: '${d.cols}×${d.rows}\n${d.mines} minas',
                              onTap: () => appState.setDifficulty(d),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'Elegí el modo'),
                    Row(
                      children: [
                        Expanded(
                          child: _OptionCard(
                            selected: appState.mode == GameMode.normal,
                            color: const Color(0xFF42A5F5),
                            emoji: '⏱️',
                            title: GameMode.normal.label,
                            subtitle: 'Sin límite\nde tiempo',
                            onTap: () => appState.setMode(GameMode.normal),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OptionCard(
                            selected: appState.mode == GameMode.contrarreloj,
                            color: const Color(0xFFAB47BC),
                            emoji: '⏳',
                            title: GameMode.contrarreloj.label,
                            subtitle: 'Tenés ${_formatTime(appState.difficulty.timeLimit)}\n¡apurate!',
                            onTap: () => appState.setMode(GameMode.contrarreloj),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _PlayButton(onPressed: () => _play(context)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            emoji: '🛒',
                            title: 'Tienda',
                            subtitle: 'Temas e íconos',
                            color: const Color(0xFF7E57C2),
                            onTap: () => _openShop(context, tab: 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SecondaryButton(
                            emoji: '📺',
                            title: 'Video gratis',
                            subtitle: '+${Catalog.rewardedAdDiamonds} 💎',
                            color: const Color(0xFF00ACC1),
                            onTap: () => _watchRewardedAd(context),
                          ),
                        ),
                      ],
                    ),
                    if (!appState.isPro) ...[
                      const SizedBox(height: 20),
                      _ProBanner(onTap: () => _openShop(context, tab: 4)),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Tocá para destapar · Mantené apretado para poner ${appState.flagEmoji}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );
}

/// Logo animado: la mina "flota" suavemente.
class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(appState.flagEmoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 8),
              Text(appState.mineEmoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(width: 8),
              const Text('🌼', style: TextStyle(fontSize: 40)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFFE91E63)],
          ).createShader(rect),
          child: const Text(
            'Buscaminas',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta seleccionable (dificultad o modo).
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.color,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        SoundService.tap();
        onTap();
      },
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))]
                : const [],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: selected ? Colors.white : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón secundario (Tienda, Video gratis).
/// Más discreto que JUGAR, pero con:
///   - fondo suave del color del botón y un ícono en un círculo,
///   - una "ola" (ripple) que sale desde donde tocaste y se desvanece,
///   - se achica un poquito mientras lo apretás y vuelve al soltar.
class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color;
    final radius = BorderRadius.circular(22);

    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: dark ? 0.22 : 0.10), scheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color.withValues(alpha: 0.55), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            SoundService.tap();
            widget.onTap();
          },
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: radius,
          // La "ola" que sale desde el dedo:
          splashFactory: InkRipple.splashFactory,
          splashColor: color.withValues(alpha: 0.35),
          // El color que toma mientras está apretado (después vuelve solo):
          highlightColor: color.withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                    ),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: dark ? Color.lerp(color, Colors.white, 0.5) : Color.lerp(color, Colors.black, 0.3),
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón grande de JUGAR que "late".
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            SoundService.tap();
            widget.onPressed();
          },
          borderRadius: BorderRadius.circular(40),
          child: Ink(
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF7CB342)]),
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [BoxShadow(color: Color(0x6643A047), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Center(
              child: Text(
                '▶  JUGAR',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundService.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFA000)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 34)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hacete PRO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF4E342E))),
                  Text('Sin publicidad · Diamantes x2 · Tema Dorado', style: TextStyle(fontSize: 12, color: Color(0xFF5D4037))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFF4E342E)),
          ],
        ),
      ),
    );
  }
}
