import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../services/sound_service.dart';

/// Botón del header para prender/apagar los sonidos y la música.
class AudioMenuButton extends StatelessWidget {
  const AudioMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha a appState para cambiar el ícono al silenciar.
    return ListenableBuilder(listenable: appState, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final muted = !appState.soundOn && !appState.musicOn;
    return PopupMenuButton<String>(
      tooltip: 'Sonido y música',
      icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onOpened: SoundService.tap,
      onSelected: (value) {
        if (value == 'sound') {
          appState.toggleSound();
          SoundService.tap();
        } else {
          appState.toggleMusic();
          SoundService.updateMusic();
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: 'sound', checked: appState.soundOn, child: const Text('🔔  Sonidos')),
        CheckedPopupMenuItem(value: 'music', checked: appState.musicOn, child: const Text('🎵  Música')),
      ],
    );
  }
}
