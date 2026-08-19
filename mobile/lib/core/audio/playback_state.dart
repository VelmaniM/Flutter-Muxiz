import 'package:flutter/material.dart';
import '../../shared/models/song.dart';

enum AudioRepeatMode {
  off,
  all,
  one,
}

class PlayerStateModel {
  final Song? currentSong;
  final List<Song> queue;
  final int queueIndex;
  final bool isPlaying;
  final bool isBuffering;
  final bool isShuffling;
  final AudioRepeatMode repeatMode;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double speed;
  final Color dominantColor;
  final String? errorMessage;

  const PlayerStateModel({
    this.currentSong,
    this.queue = const [],
    this.queueIndex = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isShuffling = false,
    this.repeatMode = AudioRepeatMode.off,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.speed = 1.0,
    this.dominantColor = const Color(0xFF181818),
    this.errorMessage,
  });

  PlayerStateModel copyWith({
    Song? currentSong,
    bool clearCurrentSong = false,
    List<Song>? queue,
    int? queueIndex,
    bool? isPlaying,
    bool? isBuffering,
    bool? isShuffling,
    AudioRepeatMode? repeatMode,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? speed,
    Color? dominantColor,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerStateModel(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isShuffling: isShuffling ?? this.isShuffling,
      repeatMode: repeatMode ?? this.repeatMode,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      speed: speed ?? this.speed,
      dominantColor: dominantColor ?? this.dominantColor,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  double get progressRatio {
    final durMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds
        : (currentSong != null ? currentSong!.duration * 1000 : 0);
    if (durMs <= 0) return 0.0;
    final ratio = position.inMilliseconds / durMs;
    return ratio.clamp(0.0, 1.0);
  }

  bool get hasNext => queue.isNotEmpty && queueIndex < queue.length - 1;
  bool get hasPrevious => queueIndex > 0 || position.inSeconds > 3;
}
