import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Capa de efectos hecha con el motor de juego **Flame**.
///
/// Es un FlameGame transparente que se dibuja ENCIMA del tablero.
/// Flame tiene su propio bucle de juego (game loop): unas 60 veces por segundo
/// llama a update() y render() de cada componente. Acá lo usamos para:
///   - Tierra que salta al destapar una casilla (partículas).
///   - Explosión con "¡BOOM!" al pisar una mina (partículas + efectos).
///   - Fuegos artificiales al ganar (partículas + temporizador).
///
/// La lógica del buscaminas sigue en models/minesweeper.dart;
/// Flame se encarga solo de la parte visual "de videojuego".
class EffectsGame extends FlameGame {
  final Random _rnd = Random();
  int _cols = 8;
  int _rows = 10;

  /// Fondo transparente: así se ve el tablero que está debajo.
  @override
  Color backgroundColor() => const Color(0x00000000);

  /// El tablero le avisa su tamaño para poder ubicar los efectos en cada casilla.
  void configureBoard(int cols, int rows) {
    _cols = cols;
    _rows = rows;
  }

  bool get _ready => isMounted && size.x > 0 && size.y > 0;

  /// Centro de una casilla en coordenadas del juego.
  /// Usa la misma cuenta que BoardView para que coincidan.
  Vector2 _cellCenter(int row, int col) {
    final cell = min((size.x - 12) / _cols, (size.y - 12) / _rows).floorToDouble();
    final boardW = cell * _cols + 12;
    final boardH = cell * _rows + 12;
    final left = (size.x - boardW) / 2 + 6;
    final top = (size.y - boardH) / 2 + 6;
    return Vector2(left + (col + 0.5) * cell, top + (row + 0.5) * cell);
  }

  /// Partícula: un círculo que se achica y se desvanece con el tiempo.
  Particle _fadingCircle(double radius, Color color) {
    return ComputedParticle(
      renderer: (canvas, particle) {
        final t = particle.progress; // va de 0 a 1 durante su vida
        final paint = Paint()..color = color.withValues(alpha: 1 - t);
        canvas.drawCircle(Offset.zero, radius * (1 - t * 0.5), paint);
      },
    );
  }

  /// Velocidad en una dirección al azar.
  Vector2 _randomVelocity(double minSpeed, double maxSpeed) {
    final angle = _rnd.nextDouble() * 2 * pi;
    final speed = minSpeed + _rnd.nextDouble() * (maxSpeed - minSpeed);
    return Vector2(cos(angle), sin(angle)) * speed;
  }

  // =================== Efectos ===================

  /// Pedacitos de césped que saltan al destapar una casilla.
  void dig(int row, int col, Color color) {
    if (!_ready) return;
    add(
      ParticleSystemComponent(
        position: _cellCenter(row, col),
        particle: Particle.generate(
          count: 10,
          lifespan: 0.5,
          generator: (_) => AcceleratedParticle(
            speed: _randomVelocity(40, 110),
            acceleration: Vector2(0, 260), // gravedad
            child: _fadingCircle(2.5 + _rnd.nextDouble() * 3, color),
          ),
        ),
      ),
    );
  }

  /// Explosión de fuego y el cartel "¡BOOM!" al pisar una mina.
  void explode(int row, int col) {
    if (!_ready) return;
    final center = _cellCenter(row, col);
    const fire = [Color(0xFFFF5722), Color(0xFFFFC107), Color(0xFFFF9800), Color(0xFFF44336)];

    // Fuego
    add(
      ParticleSystemComponent(
        position: center,
        particle: Particle.generate(
          count: 70,
          lifespan: 1.0,
          generator: (_) => AcceleratedParticle(
            speed: _randomVelocity(80, 300),
            acceleration: Vector2(0, 320),
            child: _fadingCircle(3 + _rnd.nextDouble() * 5, fire[_rnd.nextInt(fire.length)]),
          ),
        ),
      ),
    );

    // Humo gris que sube
    add(
      ParticleSystemComponent(
        position: center,
        particle: Particle.generate(
          count: 14,
          lifespan: 1.4,
          generator: (_) => AcceleratedParticle(
            speed: _randomVelocity(10, 40),
            acceleration: Vector2(0, -60),
            child: _fadingCircle(10 + _rnd.nextDouble() * 10, const Color(0x99616161)),
          ),
        ),
      ),
    );

    // Cartel "¡BOOM!" que crece, sube y desaparece (efectos de Flame)
    final textPos = Vector2(
      center.x.clamp(90.0, max(90.0, size.x - 90)).toDouble(),
      max(40.0, center.y - 30),
    );
    final boom = TextComponent(
      text: '¡BOOM!',
      anchor: Anchor.center,
      position: textPos,
      scale: Vector2.all(0.2),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFF3D00),
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(2, 2))],
        ),
      ),
    );
    boom.add(ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.35, curve: Curves.easeOutBack)));
    boom.add(MoveByEffect(Vector2(0, -40), EffectController(duration: 1.2)));
    boom.add(RemoveEffect(delay: 1.3));
    add(boom);
  }

  /// Fuegos artificiales al ganar: 10 estallidos, uno cada 0,3 segundos.
  void fireworks() {
    if (!_ready) return;
    var bursts = 0;
    late final TimerComponent timer;
    timer = TimerComponent(
      period: 0.3,
      repeat: true,
      onTick: () {
        _burst(Vector2(
          size.x * (0.15 + _rnd.nextDouble() * 0.7),
          size.y * (0.15 + _rnd.nextDouble() * 0.5),
        ));
        bursts++;
        if (bursts >= 10) timer.removeFromParent();
      },
    );
    add(timer);
    _burst(size / 2);

    // Cartel "¡GANASTE!" que rebota
    final win = TextComponent(
      text: '¡GANASTE!',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.4),
      scale: Vector2.zero(),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFEB3B),
          shadows: [Shadow(color: Color(0xCC1B5E20), blurRadius: 8, offset: Offset(3, 3))],
        ),
      ),
    );
    win.add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.6, curve: Curves.elasticOut)));
    win.add(RemoveEffect(delay: 2.5));
    add(win);
  }

  void _burst(Vector2 position) {
    const colors = [
      Color(0xFFE91E63),
      Color(0xFF2196F3),
      Color(0xFFFFEB3B),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
    ];
    final color = colors[_rnd.nextInt(colors.length)];
    add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 45,
          lifespan: 1.2,
          generator: (_) => AcceleratedParticle(
            speed: _randomVelocity(60, 200),
            acceleration: Vector2(0, 120),
            child: _fadingCircle(2.5 + _rnd.nextDouble() * 2.5, color),
          ),
        ),
      ),
    );
  }
}
