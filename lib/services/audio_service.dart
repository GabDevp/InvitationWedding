
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal();

  AudioPlayer? _player;

  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isStarting = false;

  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_player == null) {
      _player = AudioPlayer();
    }

    await _player!.setReleaseMode(ReleaseMode.loop);

    _player!.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });

    _isInitialized = true;
  }

  /// Inicia la música. Debe llamarse desde un gesto del usuario
  /// en navegadores que bloquean la reproducción automática.
  Future<void> startMusic() async {
    if (_isStarting || _isPlaying) return;

    _isStarting = true;

    try {
      await initialize();

      await _player!.play(
        UrlSource('assets/lib/assets/audio/potter_waltz.mp3'),
      );

      _isPlaying = true;
    } catch (e) {
      debugPrint('Error al iniciar la música: $e');
    } finally {
      _isStarting = false;
    }
  }

  /// Alterna entre pausa y reproducción.
  Future<void> togglePlayPause() async {
    await initialize();

    try {
      if (_isPlaying) {
        await _player!.pause();
        _isPlaying = false;
      } else {
        // Si nunca se inició la canción, play() carga el recurso.
        if (kIsWeb) {
          await _player!.play(
            UrlSource('assets/lib/assets/audio/potter_waltz.mp3'),
          );
        } else {
          await _player!.resume();
        }

        _isPlaying = true;
      }
    } catch (e) {
      debugPrint('Error al controlar la música: $e');
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();

    _player = null;
    _isPlaying = false;
    _isInitialized = false;
    _isStarting = false;
  }
}
