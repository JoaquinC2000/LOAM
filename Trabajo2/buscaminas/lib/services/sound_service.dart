import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import '../models/app_state.dart';

/// Todos los sonidos y la música del juego.
///
/// Usa flame_audio (el sistema de audio del motor Flame).
/// Los archivos están en assets/audio/ y vienen dentro de la app,
/// así que funcionan sin internet.
class SoundService {
  static const _effects = [
    'tap.wav', // botones
    'dig.wav', // destapar casilla
    'flag.wav', // poner/sacar bandera
    'explosion.wav', // pisar una mina
    'tick.wav', 'tock.wav', // reloj en los últimos 10 segundos
    'beep.wav', // últimos 3 segundos para decidir si seguir
    'time_up.wav', // se acabó el tiempo
    'win.wav', // ganaste
    'lose.wav', // perdiste
    'coin.wav', // ganar o comprar diamantes
    'power.wav', // usar un poder
  ];
  static const _music = 'music.mp3';

  static bool _ready = false;
  static bool _musicPlaying = false;

  /// Se llama una vez al abrir la app: precarga los sonidos y arranca la música.
  static Future<void> init() async {
    try {
      // bgm.initialize() pausa la música sola cuando la app pasa a segundo plano.
      FlameAudio.bgm.initialize();
      await FlameAudio.audioCache.loadAll([..._effects, _music]);
      _ready = true;
      updateMusic();
    } catch (_) {
      // Si el audio falla, el juego sigue funcionando sin sonido.
      _ready = false;
    }
  }

  /// Reproduce un efecto si el sonido está activado.
  static void play(String file) {
    if (!_ready || !appState.soundOn) return;
    unawaited(FlameAudio.play(file).then((_) {}, onError: (_) {}));
  }

  /// Prende o apaga la música según la preferencia del usuario.
  static void updateMusic() {
    if (!_ready) return;
    if (appState.musicOn && !_musicPlaying) {
      FlameAudio.bgm.play(_music, volume: 0.3);
      _musicPlaying = true;
    } else if (!appState.musicOn && _musicPlaying) {
      FlameAudio.bgm.stop();
      _musicPlaying = false;
    }
  }

  // Atajos para que el código del juego se lea fácil.
  static void tap() => play('tap.wav');
  static void dig() => play('dig.wav');
  static void flag() => play('flag.wav');
  static void explosion() => play('explosion.wav');
  static void tick(bool even) => play(even ? 'tick.wav' : 'tock.wav');
  static void beep() => play('beep.wav');
  static void timeUp() => play('time_up.wav');
  static void win() => play('win.wav');
  static void lose() => play('lose.wav');
  static void coin() => play('coin.wav');
  static void power() => play('power.wav');
}
