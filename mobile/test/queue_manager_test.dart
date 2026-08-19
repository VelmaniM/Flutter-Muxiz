import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/playback_state.dart';
import 'package:mobile/core/audio/queue_manager.dart';
import 'package:mobile/shared/models/song.dart';

void main() {
  group('QueueManager Tests', () {
    late QueueManager queueManager;
    final testSongs = List.generate(
      5,
      (i) => Song(
        id: 'song_$i',
        title: 'Song $i',
        artist: 'Artist $i',
        artworkUrl: 'https://example.com/art$i.jpg',
        audioUrl: 'https://example.com/audio$i.mp3',
        duration: 180 + i * 10,
      ),
    );

    setUp(() {
      queueManager = QueueManager();
      queueManager.setQueue(testSongs, initialIndex: 0);
    });

    test('Initial queue state is set correctly', () {
      expect(queueManager.length, 5);
      expect(queueManager.currentIndex, 0);
      expect(queueManager.currentSong?.id, 'song_0');
      expect(queueManager.isShuffling, false);
      expect(queueManager.repeatMode, AudioRepeatMode.off);
    });

    test('getNextIndex returns next song in sequence', () {
      expect(queueManager.getNextIndex(), 1);
      queueManager.setCurrentIndex(4);
      expect(queueManager.getNextIndex(), isNull);
    });

    test('Repeat ALL loops back to index 0 on last track', () {
      queueManager.setRepeatMode(AudioRepeatMode.all);
      queueManager.setCurrentIndex(4);
      expect(queueManager.getNextIndex(), 0);
    });

    test('Repeat ONE returns same index', () {
      queueManager.setRepeatMode(AudioRepeatMode.one);
      queueManager.setCurrentIndex(2);
      expect(queueManager.getNextIndex(), 2);
    });

    test('getPreviousIndex respects 3-second threshold', () {
      queueManager.setCurrentIndex(2);
      // If position > 3 seconds, replay current track
      expect(queueManager.getPreviousIndex(positionSeconds: 5), 2);
      // If position <= 3 seconds, skip to previous track
      expect(queueManager.getPreviousIndex(positionSeconds: 1), 1);
    });

    test('addToQueue and playNext correctly insert songs', () {
      const extraSong = Song(
        id: 'extra_1',
        title: 'Extra Song',
        artist: 'Artist',
        artworkUrl: '',
        audioUrl: '',
      );

      queueManager.playNext(extraSong);
      expect(queueManager.queue[1].id, 'extra_1');
      expect(queueManager.length, 6);
    });

    test('removeFromQueue adjusts current index correctly', () {
      queueManager.setCurrentIndex(3);
      queueManager.removeFromQueue(1);
      expect(queueManager.length, 4);
      expect(queueManager.currentIndex, 2);
    });

    test('reorder preserves and adjusts queue order', () {
      queueManager.reorder(0, 3);
      expect(queueManager.queue[2].id, 'song_0');
    });

    test('Shuffle preserves current song and shuffles rest', () {
      queueManager.setCurrentIndex(1);
      final currentId = queueManager.currentSong!.id;
      queueManager.setShuffle(true);
      expect(queueManager.isShuffling, true);
      expect(queueManager.currentSong?.id, currentId);
      expect(queueManager.length, 5);

      queueManager.setShuffle(false);
      expect(queueManager.isShuffling, false);
      expect(queueManager.queue.first.id, 'song_0');
    });
  });
}
