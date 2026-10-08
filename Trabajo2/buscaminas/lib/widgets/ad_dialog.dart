import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Publicidad simulada a pantalla completa.
/// Muestra un "anuncio" animado de un juego inventado y una cuenta regresiva;
/// recién al llegar a cero se puede cerrar.
///
/// Devuelve true si el anuncio se vio completo (sirve para dar premios).
Future<bool> showAdDialog(BuildContext context, {int seconds = 5, bool rewarded = false}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Publicidad',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, __) => _AdView(seconds: seconds, rewarded: rewarded),
    transitionBuilder: (context, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: child,
    ),
  );
  return result ?? false;
}

class _AdView extends StatefulWidget {
  const _AdView({required this.seconds, required this.rewarded});
  final int seconds;
  final bool rewarded;

  @override
  State<_AdView> createState() => _AdViewState();
}

class _AdViewState extends State<_AdView> with SingleTickerProviderStateMixin {
  late int _remaining = widget.seconds;
  Timer? _timer;
  late final AnimationController _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _remaining--);
      if (_remaining <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bubbles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canClose = _remaining <= 0;
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7E57C2), Color(0xFF26C6DA)],
              ),
            ),
            child: Stack(
              children: [
                // Burbujas animadas de fondo
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _bubbles,
                    builder: (context, _) => CustomPaint(painter: _BubblesPainter(_bubbles.value)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🫧', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 12),
                      const Text(
                        'Burbujas Mágicas',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '¡Explotá burbujas de colores y salvá a los pececitos!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF7E57C2)),
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Descargar gratis'),
                      ),
                      if (widget.rewarded) ...[
                        const SizedBox(height: 16),
                        Text(
                          canClose ? '¡Listo! Ganaste tu premio 💎' : 'Mirá el anuncio completo para ganar 💎',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
                // Etiqueta "Publicidad"
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Publicidad', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
                // Cuenta regresiva o botón de cerrar
                Positioned(
                  right: 10,
                  top: 10,
                  child: canClose
                      ? IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          tooltip: 'Cerrar',
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: Text(
                            '$_remaining',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
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

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7); // misma semilla = mismas burbujas en cada cuadro
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 14; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.5 + rnd.nextDouble();
      final radius = 8 + rnd.nextDouble() * 22;
      final y = size.height - ((t * speed + rnd.nextDouble()) % 1.0) * (size.height + 60) + 30;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.t != t;
}
