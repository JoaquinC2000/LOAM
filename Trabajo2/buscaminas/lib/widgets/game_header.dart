import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/sound_service.dart';

/// Un dato que se muestra en la segunda fila del header.
class HeaderStat {
  const HeaderStat({required this.emoji, required this.label, required this.value, this.warning = false, this.onTap});

  final String emoji;
  final String label;
  final String value;

  /// Si es true se pinta en rojo y late (ej: quedan pocos segundos).
  final bool warning;

  /// Si no es null, la pastilla se puede tocar (ej: Tema → abre la tienda de temas).
  final VoidCallback? onTap;
}

/// Header de la app. Para que entre todo en un celular se divide en dos filas:
///   1) Quién sos: avatar, nombre, cuenta BASIC/PRO y diamantes (con botón +).
///   2) Cómo vas: los datos de la partida (puntaje, tiempo, banderas...).
class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    this.stats = const [],
    this.onDiamondsTap,
    this.onBack,
    this.actions = const [],
  });

  final List<HeaderStat> stats;
  final VoidCallback? onDiamondsTap;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final dark = appState.isDark;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF1B3A1E), Color(0xFF2E4F1F)]
                  : const [Color(0xFF43A047), Color(0xFF7CB342)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUserRow(context),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildStatsRow(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserRow(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            onPressed: () {
              SoundService.tap();
              onBack!();
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Volver',
          ),
        // Avatar
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: appState.isPro ? const Color(0xFFFFC107) : Colors.white70, width: 3),
          ),
          child: Text(appState.avatar, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 10),
        // Nombre + tipo de cuenta
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.userName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              _AccountBadge(isPro: appState.isPro),
            ],
          ),
        ),
        ...actions,
        _DiamondChip(amount: appState.diamonds, onTap: onDiamondsTap),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _StatPill(stat: stats[i])),
        ],
      ],
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: isPro
            ? const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFA000)])
            : const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPro ? '👑 PRO' : 'BASIC',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: isPro ? const Color(0xFF5D4037) : const Color(0xFF424242),
        ),
      ),
    );
  }
}

class _DiamondChip extends StatelessWidget {
  const _DiamondChip({required this.amount, this.onTap});
  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap == null
            ? null
            : () {
                SoundService.tap();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              // AnimatedSwitcher hace una animación cuando cambia el número.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$amount',
                  key: ValueKey(amount),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1565C0)),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.stat});
  final HeaderStat stat;

  @override
  Widget build(BuildContext context) {
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: stat.warning ? const Color(0xFFE53935) : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        // Las pastillas que se pueden tocar tienen un borde blanco suave.
        border: Border.all(color: stat.onTap != null ? Colors.white54 : Colors.transparent, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(stat.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stat.value,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (stat.onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white30,
        onTap: () {
          SoundService.tap();
          stat.onTap!();
        },
        child: pill,
      ),
    );
  }
}
