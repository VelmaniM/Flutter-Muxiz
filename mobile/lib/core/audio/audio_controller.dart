import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/models/song.dart';
import '../../shared/models/listening_activity.dart';
import '../data/mock_catalog.dart';
import '../services/listening_tracker_service.dart';
import '../storage/local_storage.dart';
import 'audio_handler.dart';
import 'playback_state.dart';

final audioHandlerProvider = Provider<MuxizAudioHandler>((ref) {
  return MuxizAudioHandler();
});

final playerStateProvider = StateNotifierProvider<AudioController, PlayerStateModel>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return AudioController(handler);
});

class AudioController extends StateNotifier<PlayerStateModel> {
  final MuxizAudioHandler _handler;
  DateTime _lastSaveTime = DateTime.now();
  final List<StreamSubscription> _subscriptions = [];

  AudioController(this._handler) : super(_getInitialState()) {
    _handler.onSkipToNext = skipToNext;
    _handler.onSkipToPrevious = skipToPrevious;
    _initListeners();
    _restoreLastPlaybackState().catchError((_) {});
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  static PlayerStateModel _getInitialState() {
    try {
      final last = LocalStorageService.getLastPlaybackState();
      if (last.song != null) {
        final song = last.song!;
        final queue = last.queue.isNotEmpty ? last.queue : [song];
        final queueIdx = (last.queueIndex >= 0 && last.queueIndex < queue.length)
            ? last.queueIndex
            : 0;
        return PlayerStateModel(
          currentSong: song,
          queue: queue,
          queueIndex: queueIdx,
          position: last.position,
          duration: Duration(seconds: song.duration > 0 ? song.duration : 180),
          isPlaying: false,
        );
      }
    } catch (_) {}
    return const PlayerStateModel();
  }

  void _initListeners() {
    // 1. Playback & Buffering State
    _subscriptions.add(_handler.playerService.playerStateStream.listen((stateEvent) {
      if (!mounted) return;
      final isPlaying = stateEvent.playing;
      final isBuffering = stateEvent.processingState == ProcessingState.buffering ||
          stateEvent.processingState == ProcessingState.loading;
      final isCompleted = stateEvent.processingState == ProcessingState.completed;

      // When track reaches completion, pin position cleanly to exact duration
      final accuratePosition = isCompleted && state.duration > Duration.zero
          ? state.duration
          : state.position;

      state = state.copyWith(
        isPlaying: isCompleted ? false : isPlaying,
        isBuffering: isBuffering,
        position: accuratePosition,
      );

      if (state.currentSong != null) {
        LocalStorageService.savePlaybackState(
          song: state.currentSong!,
          position: accuratePosition,
          queue: state.queue,
          queueIndex: state.queueIndex,
        );
      }
    }));

    // 2. Continuous Background Song Sequence / Index Updates (Exact Match with Audio Source)
    _subscriptions.add(_handler.playerService.sequenceStateStream.listen((seqState) {
      if (!mounted || seqState == null) return;
      final tag = seqState.currentSource?.tag;
      if (tag is MediaItem) {
        final songId = tag.id;
        final targetIndex = state.queue.indexWhere((s) => s.id == songId);
        if (targetIndex != -1 && (state.currentSong?.id != songId || state.queueIndex != targetIndex)) {
          final currentSong = state.queue[targetIndex];
          state = state.copyWith(
            currentSong: currentSong,
            queueIndex: targetIndex,
            position: Duration.zero,
            duration: Duration(seconds: currentSong.duration),
            clearError: true,
          );
          LocalStorageService.addRecentlyPlayed(currentSong);
          LocalStorageService.savePlaybackState(
            song: currentSong,
            position: Duration.zero,
            queue: state.queue,
            queueIndex: targetIndex,
          );
          _extractPaletteColor(currentSong.artworkUrl);
        }
      }
    }));

    // 3. Position Stream with exact duration clamping
    _subscriptions.add(_handler.playerService.positionStream.listen((pos) {
      if (!mounted) return;
      // Do not overwrite restored state position with zero if audio player is idle
      if (!state.isPlaying && _handler.player.audioSource == null) {
        return;
      }
      final accurateDuration = state.duration;
      final clampedPos = (accurateDuration > Duration.zero && pos > accurateDuration)
          ? accurateDuration
          : (pos < Duration.zero ? Duration.zero : pos);

      state = state.copyWith(position: clampedPos);

      // Track progress for meaningful listen calculation (>=30s or >=25%)
      if (state.currentSong != null && state.isPlaying) {
        ListeningTrackerService.instance.onPositionUpdated(
          state.currentSong!,
          clampedPos,
          state.duration,
        );
      }

      final now = DateTime.now();
      if (state.currentSong != null && now.difference(_lastSaveTime).inSeconds >= 2) {
        _lastSaveTime = now;
        LocalStorageService.savePlaybackState(
          song: state.currentSong!,
          position: clampedPos,
          queue: state.queue,
          queueIndex: state.queueIndex,
        );
      }
    }));

    // 4. Duration Stream with dynamic track sync
    _subscriptions.add(_handler.playerService.durationStream.listen((dur) {
      if (!mounted) return;
      if (dur != null && dur > Duration.zero) {
        state = state.copyWith(duration: dur);
      }
    }));

    // 5. Buffered Position Stream
    _subscriptions.add(_handler.playerService.bufferedPositionStream.listen((buffered) {
      if (!mounted) return;
      state = state.copyWith(bufferedPosition: buffered);
    }));
  }

  /// Automatically restore the last played song and position on app restart
  Future<void> _restoreLastPlaybackState() async {
    try {
      final last = LocalStorageService.getLastPlaybackState();
      if (last.song != null) {
        final song = last.song!;
        final queue = last.queue.isNotEmpty ? last.queue : [song];
        final queueIdx = (last.queueIndex >= 0 && last.queueIndex < queue.length)
            ? last.queueIndex
            : 0;

        state = state.copyWith(
          currentSong: song,
          queue: queue,
          queueIndex: queueIdx,
          position: last.position,
          duration: Duration(seconds: song.duration > 0 ? song.duration : 180),
          isPlaying: false,
        );

        _extractPaletteColor(song.artworkUrl);

        debugPrint('[PLAYER_RESTORE] Restored media item: "${song.title}" (${song.id})');
        debugPrint('[PLAYER_RESTORE] Restored position: ${last.position.inSeconds}s (Duration: ${song.duration}s)');

        try {
          await _handler.setQueue(
            queue,
            initialIndex: queueIdx,
            initialPosition: last.position,
            autoPlay: false,
          ).catchError((_) {});
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Play a song with automatic continuous queue generation and optional seek position
  Future<void> playSong(Song song, {List<Song>? queue, int? index, Duration? startPosition}) async {
    final isDown = song.isDownloaded || LocalStorageService.getDownloadedSongs().any((s) => s.id == song.id);
    final resolvedSong = song.copyWith(isDownloaded: isDown);

    List<Song> effectiveQueue;
    int targetIndex = 0;

    if (queue != null && queue.isNotEmpty) {
      effectiveQueue = List<Song>.from(queue);
      final foundIdx = effectiveQueue.indexWhere((s) => s.id == song.id);
      if (foundIdx != -1) {
        effectiveQueue[foundIdx] = resolvedSong;
        targetIndex = foundIdx;
      } else {
        effectiveQueue.insert(0, resolvedSong);
        targetIndex = 0;
      }
    } else {
      effectiveQueue = [resolvedSong];
      final otherSongs = MockMusicCatalog.allSongs.where((s) => s.id != resolvedSong.id).toList();
      if (otherSongs.isNotEmpty) {
        effectiveQueue.addAll(otherSongs);
      }
      targetIndex = 0;
    }

    final pos = startPosition ?? Duration.zero;

    // Start tracking playback session in ListeningTrackerService
    ListeningTrackerService.instance.onSongStarted(resolvedSong);
    ListeningTrackerService.instance.recordFastLocalOpen(
      resolvedSong.id,
      resolvedSong.title,
      QuickAccessContentType.song,
      resolvedSong.artworkUrl,
      subtitle: resolvedSong.artist,
    );

    LocalStorageService.addRecentlyPlayed(resolvedSong);
    LocalStorageService.savePlaybackState(
      song: resolvedSong,
      position: pos,
      queue: effectiveQueue,
      queueIndex: targetIndex,
    );

    state = state.copyWith(
      currentSong: resolvedSong,
      queue: effectiveQueue,
      queueIndex: targetIndex,
      position: pos,
      duration: Duration(seconds: resolvedSong.duration),
      isPlaying: true,
      clearError: true,
    );

    _extractPaletteColor(resolvedSong.artworkUrl);

    // Instant playback triggering for the exact targetIndex
    await _handler.setQueue(
      effectiveQueue,
      initialIndex: targetIndex,
      initialPosition: pos,
      autoPlay: true,
    );
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong == null) {
      if (state.queue.isNotEmpty) {
        await playSong(state.queue[0], queue: state.queue, index: 0);
      } else if (MockMusicCatalog.allSongs.isNotEmpty) {
        await playSong(MockMusicCatalog.allSongs[0]);
      }
      return;
    }

    if (state.isPlaying) {
      await _handler.pause();
      if (state.currentSong != null) {
        LocalStorageService.savePlaybackState(
          song: state.currentSong!,
          position: state.position,
          queue: state.queue,
          queueIndex: state.queueIndex,
        );
      }
    } else {
      final currentSong = state.currentSong!;
      final queue = state.queue.isNotEmpty ? state.queue : [currentSong];
      final pos = state.position;

      if (_handler.player.audioSource == null || _handler.player.processingState == ProcessingState.idle) {
        await playSong(currentSong, queue: queue, index: state.queueIndex, startPosition: pos);
      } else {
        if (pos > Duration.zero && (_handler.player.position - pos).abs() > const Duration(seconds: 1)) {
          await _handler.seek(pos);
        }
        await _handler.play();
      }
    }
  }

  Future<void> seek(Duration position) async {
    final maxDur = state.duration;
    final clamped = (maxDur > Duration.zero && position > maxDur)
        ? maxDur
        : (position < Duration.zero ? Duration.zero : position);

    state = state.copyWith(position: clamped);
    await _handler.seek(clamped);

    if (state.currentSong != null) {
      LocalStorageService.savePlaybackState(
        song: state.currentSong!,
        position: clamped,
        queue: state.queue,
        queueIndex: state.queueIndex,
      );
    }
  }

  Future<void> skipToNext() async {
    if (_handler.playerService.hasNext) {
      await _handler.playerService.seekToNext();
      await _handler.playerService.play();
    } else if (state.queue.isNotEmpty) {
      if (state.repeatMode == AudioRepeatMode.all) {
        await _handler.playerService.seek(Duration.zero, index: 0);
        await _handler.playerService.play();
      } else if (state.queueIndex < state.queue.length - 1) {
        final nextIdx = state.queueIndex + 1;
        await _handler.playerService.seek(Duration.zero, index: nextIdx);
        await _handler.playerService.play();
      }
    }
  }

  Future<void> skipToPrevious() async {
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_handler.playerService.hasPrevious) {
      await _handler.playerService.seekToPrevious();
      await _handler.playerService.play();
    } else if (state.queue.isNotEmpty && state.repeatMode == AudioRepeatMode.all) {
      await _handler.playerService.seek(Duration.zero, index: state.queue.length - 1);
      await _handler.playerService.play();
    } else {
      await seek(Duration.zero);
    }
  }

  void addToQueue(Song song) {
    if (state.currentSong == null) {
      playSong(song);
      return;
    }
    final updatedQueue = List<Song>.from(state.queue);
    final existingIdx = updatedQueue.indexWhere((s) => s.id == song.id);
    if (existingIdx != -1 && existingIdx != state.queueIndex) {
      updatedQueue.removeAt(existingIdx);
      _handler.removeFromQueueSong(existingIdx);
    }
    updatedQueue.add(song);
    state = state.copyWith(queue: updatedQueue);
    _handler.addToQueueSong(song);
  }

  void playNext(Song song) {
    if (state.currentSong == null) {
      playSong(song);
      return;
    }
    if (state.currentSong?.id == song.id) return;

    final updatedQueue = List<Song>.from(state.queue);
    final existingIdx = updatedQueue.indexWhere((s) => s.id == song.id);
    if (existingIdx != -1 && existingIdx != state.queueIndex) {
      updatedQueue.removeAt(existingIdx);
    }

    final nextIndex = (state.queueIndex + 1).clamp(0, updatedQueue.length);
    updatedQueue.insert(nextIndex, song);
    state = state.copyWith(queue: updatedQueue);
    _handler.playNextSong(song);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final updatedQueue = List<Song>.from(state.queue)..removeAt(index);
    int newIndex = state.queueIndex;
    if (index < state.queueIndex) {
      newIndex = (state.queueIndex - 1).clamp(0, updatedQueue.length - 1);
    } else if (newIndex >= updatedQueue.length) {
      newIndex = (updatedQueue.length - 1).clamp(0, updatedQueue.length - 1);
    }
    state = state.copyWith(queue: updatedQueue, queueIndex: newIndex);
    _handler.removeFromQueueSong(index);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.queue.length) return;
    if (newIndex < 0 || newIndex > state.queue.length) return;
    final updatedQueue = List<Song>.from(state.queue);
    var dest = newIndex;
    if (oldIndex < dest) dest -= 1;
    final item = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(dest, item);

    int newCurrent = state.queueIndex;
    if (state.queueIndex == oldIndex) {
      newCurrent = dest;
    } else if (oldIndex < state.queueIndex && dest >= state.queueIndex) {
      newCurrent -= 1;
    } else if (oldIndex > state.queueIndex && dest <= state.queueIndex) {
      newCurrent += 1;
    }

    state = state.copyWith(queue: updatedQueue, queueIndex: newCurrent);
    _handler.reorderQueueSong(oldIndex, newIndex);
  }

  void toggleShuffle() {
    final newShuffle = !state.isShuffling;
    state = state.copyWith(isShuffling: newShuffle);
    _handler.playerService.setShuffleModeEnabled(newShuffle);
  }

  void toggleRepeat() {
    switch (state.repeatMode) {
      case AudioRepeatMode.off:
        state = state.copyWith(repeatMode: AudioRepeatMode.all);
        _handler.playerService.setLoopMode(LoopMode.all);
        break;
      case AudioRepeatMode.all:
        state = state.copyWith(repeatMode: AudioRepeatMode.one);
        _handler.playerService.setLoopMode(LoopMode.one);
        break;
      case AudioRepeatMode.one:
        state = state.copyWith(repeatMode: AudioRepeatMode.off);
        _handler.playerService.setLoopMode(LoopMode.off);
        break;
    }
  }

  Future<void> _extractPaletteColor(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) {
        state = state.copyWith(dominantColor: const Color(0xFF181818));
        return;
      }

      ImageProvider provider;
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        provider = CachedNetworkImageProvider(imageUrl);
      } else {
        provider = NetworkImage(imageUrl);
      }

      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(provider, width: 80, height: 80),
        maximumColorCount: 16,
        timeout: const Duration(seconds: 2),
      );

      final vibrantColor = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.mutedColor?.color ??
          const Color(0xFF181818);

      state = state.copyWith(dominantColor: vibrantColor);
    } catch (_) {
      state = state.copyWith(dominantColor: const Color(0xFF181818));
    }
  }
}
