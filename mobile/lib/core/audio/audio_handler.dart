import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';
import 'audio_player_service.dart';
import 'audio_session_manager.dart';
import 'audio_source_manager.dart';
import 'queue_manager.dart';

class MuxizAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayerService _playerService = AudioPlayerService();
  final AudioSessionManager _sessionManager = AudioSessionManager();
  final QueueManager _queueManager = QueueManager();

  AudioPlayer get player => _playerService.player;
  AudioPlayerService get playerService => _playerService;
  AudioSessionManager get sessionManager => _sessionManager;
  QueueManager get queueManager => _queueManager;

  // External hooks for UI / Controller if needed
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  MuxizAudioHandler() {
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    _initSession();
    _initStreams();
  }

  Future<void> _initSession() async {
    _sessionManager.onPauseRequested = pause;
    _sessionManager.onResumeRequested = play;
    _sessionManager.onDuckVolumeRequested = (vol) => _playerService.setVolume(vol);
    await _sessionManager.initialize();
  }

  void _initStreams() {
    // 1. Playback State Stream
    _playerService.playerStateStream.listen((stateEvent) {
      final playing = stateEvent.playing;
      final isCompleted = stateEvent.processingState == ProcessingState.completed;
      final pState = switch (stateEvent.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

      final currentDur = _playerService.duration ?? Duration.zero;
      final accuratePos = isCompleted && currentDur > Duration.zero
          ? currentDur
          : _playerService.position;

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
            MediaAction.setRepeatMode,
            MediaAction.setShuffleMode,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: pState,
          playing: isCompleted ? false : playing,
          updatePosition: accuratePos,
          bufferedPosition: _playerService.player.bufferedPosition,
          speed: (playing && !isCompleted) ? _playerService.player.speed : 0.0,
          queueIndex: _queueManager.currentIndex,
        ),
      );
    });

    // 2. Sequence State & Current Index Stream (Exact Active Audio Source Tracking)
    _playerService.sequenceStateStream.listen((seqState) {
      if (seqState == null) return;
      final currentSource = seqState.currentSource;
      final tag = currentSource?.tag;
      if (tag is MediaItem) {
        mediaItem.add(tag);
        final matchIdx = _queueManager.queue.indexWhere((s) => s.id == tag.id);
        if (matchIdx != -1 && matchIdx != _queueManager.currentIndex) {
          _queueManager.setCurrentIndex(matchIdx);
          playbackState.add(
            playbackState.value.copyWith(
              updatePosition: Duration.zero,
              queueIndex: matchIdx,
            ),
          );
        }
      }
    });

    // 3. Duration Stream
    _playerService.durationStream.listen((duration) {
      if (mediaItem.value != null && duration != null && duration > Duration.zero) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }

  /// Sets queue and initializes native gapless background audio
  Future<void> setQueue(
    List<Song> songs, {
    int initialIndex = 0,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    if (songs.isEmpty) return;

    _queueManager.setQueue(songs, initialIndex: initialIndex);

    try {
      await _sessionManager.activate();
    } catch (_) {}

    final mediaItems = songs.map(AudioSourceManager.createMediaItem).toList();
    queue.add(mediaItems);

    final safeIndex = (initialIndex >= 0 && initialIndex < songs.length) ? initialIndex : 0;
    mediaItem.add(mediaItems[safeIndex]);

    try {
      await _playerService.loadPlaylist(
        songs,
        initialIndex: safeIndex,
        initialPosition: initialPosition,
        autoPlay: autoPlay,
      );
    } catch (_) {}
  }

  void setSongQueue(List<Song> songs) {
    _queueManager.setQueue(songs);
    final mediaItems = songs.map(AudioSourceManager.createMediaItem).toList();
    queue.add(mediaItems);
  }

  void addToQueueSong(Song song) {
    _queueManager.addToQueue(song);
    final item = AudioSourceManager.createMediaItem(song);
    final currentList = List<MediaItem>.from(queue.value);
    currentList.removeWhere((m) => m.id == song.id);
    currentList.add(item);
    queue.add(currentList);
    _playerService.addAudioSource(AudioSourceManager.createAudioSource(song));
  }

  void playNextSong(Song song) {
    _queueManager.playNext(song);
    final item = AudioSourceManager.createMediaItem(song);
    final currentList = List<MediaItem>.from(queue.value);
    currentList.removeWhere((m) => m.id == song.id);
    final nextIdx = (_queueManager.currentIndex + 1).clamp(0, currentList.length);
    currentList.insert(nextIdx, item);
    queue.add(currentList);
    _playerService.insertAudioSource(nextIdx, AudioSourceManager.createAudioSource(song));
  }

  void removeFromQueueSong(int index) {
    if (index < 0 || index >= _queueManager.length) return;
    _queueManager.removeFromQueue(index);
    final currentList = List<MediaItem>.from(queue.value);
    if (index < currentList.length) {
      currentList.removeAt(index);
      queue.add(currentList);
    }
    _playerService.removeAudioSourceAt(index);
  }

  void reorderQueueSong(int oldIndex, int newIndex) {
    _queueManager.reorder(oldIndex, newIndex);
    final currentList = List<MediaItem>.from(queue.value);
    if (oldIndex >= 0 && oldIndex < currentList.length && newIndex >= 0 && newIndex <= currentList.length) {
      var dest = newIndex;
      if (oldIndex < dest) dest -= 1;
      final item = currentList.removeAt(oldIndex);
      currentList.insert(dest, item);
      queue.add(currentList);
      _playerService.moveAudioSource(oldIndex, dest);
    }
  }

  Future<void> setSong(Song song, {bool autoPlay = true, Duration? initialPosition}) async {
    await setQueue([song], initialIndex: 0, initialPosition: initialPosition, autoPlay: autoPlay);
  }

  @override
  Future<void> play() async {
    await _sessionManager.activate();
    return _playerService.play();
  }

  @override
  Future<void> pause() => _playerService.pause();

  @override
  Future<void> seek(Duration position) => _playerService.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playerService.hasNext) {
      await _playerService.seekToNext();
      await _playerService.play();
    } else if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playerService.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_playerService.hasPrevious) {
      await _playerService.seekToPrevious();
      await _playerService.play();
    } else if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queueManager.length) {
      await _playerService.seek(Duration.zero, index: index);
      await _playerService.play();
    }
  }

  @override
  Future<void> fastForward([Duration duration = const Duration(seconds: 10)]) async {
    final target = _playerService.position + duration;
    final max = _playerService.duration ?? Duration.zero;
    if (target < max) {
      await seek(target);
    } else {
      await skipToNext();
    }
  }

  @override
  Future<void> rewind([Duration duration = const Duration(seconds: 10)]) async {
    final target = _playerService.position - duration;
    if (target > Duration.zero) {
      await seek(target);
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> stop() async {
    await _playerService.stop();
    return super.stop();
  }

  @override
  Future<void> setSpeed(double speed) => _playerService.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _playerService.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _playerService.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _playerService.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    await _playerService.setShuffleModeEnabled(enabled);
  }
}
