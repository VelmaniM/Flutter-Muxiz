import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/playback_state.dart';
import 'package:mobile/shared/models/song.dart';

void main() {
  group('PlayerStateModel Tests', () {
    const testSong = Song(
      id: 'test_song',
      title: 'Test Song',
      artist: 'Test Artist',
      artworkUrl: 'https://example.com/art.jpg',
      audioUrl: 'https://example.com/audio.mp3',
      duration: 200,
    );

    test('Default constructor values', () {
      const state = PlayerStateModel();
      expect(state.currentSong, isNull);
      expect(state.isPlaying, false);
      expect(state.isBuffering, false);
      expect(state.isShuffling, false);
      expect(state.repeatMode, AudioRepeatMode.off);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
    });

    test('progressRatio calculates progress accurately', () {
      final state = const PlayerStateModel().copyWith(
        position: const Duration(seconds: 50),
        duration: const Duration(seconds: 200),
      );
      expect(state.progressRatio, 0.25);
    });

    test('copyWith properly updates and preserves immutability', () {
      final state1 = const PlayerStateModel().copyWith(
        currentSong: testSong,
        isPlaying: true,
        queue: [testSong],
        queueIndex: 0,
      );

      expect(state1.currentSong?.id, 'test_song');
      expect(state1.isPlaying, true);

      final state2 = state1.copyWith(isPlaying: false);
      expect(state2.isPlaying, false);
      expect(state2.currentSong?.id, 'test_song');
      expect(state1.isPlaying, true); // state1 unchanged
    });

    test('clearCurrentSong works properly', () {
      final state1 = const PlayerStateModel().copyWith(currentSong: testSong);
      expect(state1.currentSong, isNotNull);

      final state2 = state1.copyWith(clearCurrentSong: true);
      expect(state2.currentSong, isNull);
    });
  });
}
