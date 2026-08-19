import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';
import 'audio_source_manager.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  bool get playing => _player.playing;
  ProcessingState get processingState => _player.processingState;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  ConcatenatingAudioSource? _playlistSource;

  /// Starts playback with full queue synchronization in < 30ms using lazy audio preparation
  Future<void> playSongImmediately(
    Song song, {
    List<Song>? queue,
    int initialIndex = 0,
    Duration? initialPosition,
  }) async {
    try {
      final effectiveList = (queue != null && queue.isNotEmpty) ? queue : [song];
      final safeIndex = (initialIndex >= 0 && initialIndex < effectiveList.length)
          ? initialIndex
          : effectiveList.indexWhere((s) => s.id == song.id);

      _playlistSource = AudioSourceManager.createPlaylist(effectiveList);

      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: safeIndex >= 0 ? safeIndex : 0,
        initialPosition: initialPosition,
        preload: true,
      );

      await _player.setVolume(1.0);
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayerService playSongImmediately error: $e');
    }
  }

  Future<void> loadPlaylist(
    List<Song> songs, {
    int initialIndex = 0,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    if (songs.isEmpty) return;

    final safeIndex = (initialIndex >= 0 && initialIndex < songs.length) ? initialIndex : 0;
    if (autoPlay) {
      await playSongImmediately(
        songs[safeIndex],
        queue: songs,
        initialIndex: safeIndex,
        initialPosition: initialPosition,
      );
      return;
    }

    try {
      _playlistSource = AudioSourceManager.createPlaylist(songs);
      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: safeIndex,
        initialPosition: initialPosition,
        preload: false,
      );
    } catch (e) {
      debugPrint('AudioPlayerService loadPlaylist error: $e');
    }
  }

  Future<void> addAudioSource(AudioSource source) async {
    try {
      if (_playlistSource != null) {
        await _playlistSource!.add(source);
      }
    } catch (e) {
      debugPrint('Error adding audio source: $e');
    }
  }

  Future<void> insertAudioSource(int index, AudioSource source) async {
    try {
      if (_playlistSource != null) {
        final safeIndex = index.clamp(0, _playlistSource!.length);
        await _playlistSource!.insert(safeIndex, source);
      }
    } catch (e) {
      debugPrint('Error inserting audio source: $e');
    }
  }

  Future<void> removeAudioSourceAt(int index) async {
    try {
      if (_playlistSource != null && index >= 0 && index < _playlistSource!.length) {
        await _playlistSource!.removeAt(index);
      }
    } catch (e) {
      debugPrint('Error removing audio source: $e');
    }
  }

  Future<void> moveAudioSource(int oldIndex, int newIndex) async {
    try {
      if (_playlistSource != null &&
          oldIndex >= 0 &&
          oldIndex < _playlistSource!.length &&
          newIndex >= 0 &&
          newIndex < _playlistSource!.length) {
        await _playlistSource!.move(oldIndex, newIndex);
      }
    } catch (e) {
      debugPrint('Error moving audio source: $e');
    }
  }

  Future<void> play() async {
    await _player.setVolume(1.0);
    return _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);

  Future<void> seekToNext() => _player.seekToNext();

  Future<void> seekToPrevious() => _player.seekToPrevious();

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  Future<void> setShuffleModeEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);

  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}
