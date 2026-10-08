import 'dart:math';

import 'package:flutter/material.dart';

/// Lluvia de papelitos de colores para festejar cuando ganás.
/// Se dibuja con un CustomPainter, sin librerías externas.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  late final List<_Piece> _pieces = List.generate(90, (_) => _Piece(Random()));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller.value),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.35,
        speed = 0.7 + r.nextDouble() * 0.6,
        drift = (r.nextDouble() - 0.5) * 0.3,
        spin = r.nextDouble() * 10,
        width = 6 + r.nextDouble() * 6,
        color = _colors[r.nextInt(_colors.length)];

  static const _colors = [
    Color(0xFFE91E63),
    Color(0xFF2196F3),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
    Color(0xFFFF5722),
  ];

  final double x, delay, speed, drift, spin, width;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0).toDouble();
      if (local <= 0) continue;
      final dx = (p.x + p.drift * local + sin(local * 12 + p.spin) * 0.02) * size.width;
      final dy = -20 + local * p.speed * (size.height + 40);
      final paint = Paint()..color = p.color.withValues(alpha: 1 - local * 0.6);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(local * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.width, height: p.width * 0.5), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
