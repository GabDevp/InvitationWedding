
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal();

  AudioPlayer? _player;

  bool _isPlaying = false;
  bool _isInitialized = false;

  bool get isPlaying => _isPlaying;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    _player = AudioPlayer();
    await _player!.setReleaseMode(ReleaseMode.loop);

    _player!.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });

    _isInitialized = true;
  }

  Future<void> togglePlayPause() async {
    await _ensureInitialized();

    try {
      if (_isPlaying) {
        await _player!.pause();
      } else {
        // En web, usar UrlSource con la ruta correcta del asset
        if (kIsWeb) {
          await _player!.play(
            UrlSource('assets/lib/assets/audio/potter_waltz.mp3'),
          );
        } else {
          await _player!.play(
            UrlSource('assets/lib/assets/audio/potter_waltz.mp3'),
          );
        }
      }
    } catch (e) {
      debugPrint('AudioService error: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();

    _player = null;
    _isPlaying = false;
    _isInitialized = false;
  }
}
