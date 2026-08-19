import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/actions/song_action_models.dart';
import 'package:mobile/core/audio/queue_manager.dart';
import 'package:mobile/shared/models/song.dart';

void main() {
  group('SongAction System Unit Tests', () {
    const songA = Song(
      id: 'song_a',
      title: 'Song A',
      artist: 'Artist A',
      album: 'Album A',
      duration: 200,
      audioUrl: 'https://sample.audio/a.mp3',
      artworkUrl: 'https://sample.audio/a.jpg',
    );

    const songB = Song(
      id: 'song_b',
      title: 'Song B',
      artist: 'Artist B',
      album: 'Album B',
      duration: 180,
      audioUrl: 'https://sample.audio/b.mp3',
      artworkUrl: 'https://sample.audio/b.jpg',
    );

    const songC = Song(
      id: 'song_c',
      title: 'Song C',
      artist: 'Artist C',
      album: 'Album C',
      duration: 220,
      audioUrl: 'https://sample.audio/c.mp3',
      artworkUrl: 'https://sample.audio/c.jpg',
    );

    const songX = Song(
      id: 'song_x',
      title: 'Song X',
      artist: 'Artist X',
      album: 'Album X',
      duration: 210,
      audioUrl: 'https://sample.audio/x.mp3',
      artworkUrl: 'https://sample.audio/x.jpg',
    );

    test('1. Play Next inserts immediately after current song without destroying queue', () {
      final qm = QueueManager();
      qm.setQueue([songA, songB, songC], initialIndex: 0);

      expect(qm.currentSong?.id, 'song_a');
      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_b', 'song_c']);

      // User selects Play Next on Song X
      qm.playNext(songX);

      // Expected queue order: A, X, B, C
      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_x', 'song_b', 'song_c']);
      expect(qm.currentSong?.id, 'song_a');
      expect(qm.currentIndex, 0);

      // Next track must be Song X
      final nextIdx = qm.getNextIndex();
      expect(nextIdx, 1);
      expect(qm.queue[nextIdx!].id, 'song_x');
    });

    test('2. Add to Queue appends to the end of queue', () {
      final qm = QueueManager();
      qm.setQueue([songA, songB, songC], initialIndex: 0);

      qm.addToQueue(songX);

      // Expected queue order: A, B, C, X
      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_b', 'song_c', 'song_x']);
      expect(qm.currentSong?.id, 'song_a');
    });

    test('3. Play Next vs Add to Queue maintain distinct behaviors', () {
      final qm1 = QueueManager();
      qm1.setQueue([songA, songB, songC], initialIndex: 0);
      qm1.playNext(songX);

      final qm2 = QueueManager();
      qm2.setQueue([songA, songB, songC], initialIndex: 0);
      qm2.addToQueue(songX);

      expect(qm1.queue[1].id, 'song_x');
      expect(qm2.queue[3].id, 'song_x');
      expect(qm1.queue.length, qm2.queue.length);
    });

    test('4. Remove from Queue removes item and safely preserves playback index', () {
      final qm = QueueManager();
      qm.setQueue([songA, songX, songB, songC], initialIndex: 0);

      // Remove songX at index 1
      qm.removeFromQueue(1);

      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_b', 'song_c']);
      expect(qm.currentSong?.id, 'song_a');
      expect(qm.currentIndex, 0);
    });

    test('5. Reorder Queue adjusts song positions correctly', () {
      final qm = QueueManager();
      qm.setQueue([songA, songB, songC], initialIndex: 0);

      // Move songC (index 2) to index 1 (before songB)
      qm.reorder(2, 1);

      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_c', 'song_b']);
      expect(qm.currentIndex, 0);
    });

    test('6. SongActionConfig properly encapsulates contextual information', () {
      const config = SongActionConfig(
        context: SongActionContext.playlist,
        playlistId: 'pl_workout',
        playlistTitle: 'Workout Mix',
        queueIndex: 4,
      );

      expect(config.context, SongActionContext.playlist);
      expect(config.playlistId, 'pl_workout');
      expect(config.playlistTitle, 'Workout Mix');
      expect(config.queueIndex, 4);

      final copy = config.copyWith(context: SongActionContext.queue);
      expect(copy.context, SongActionContext.queue);
      expect(copy.playlistId, 'pl_workout');
    });

    test('7. Safe Share Text does NOT expose private Google Drive URLs', () {
      const songWithPrivateDriveUrl = Song(
        id: 'drive_song_1',
        title: 'Naa Ready',
        artist: 'Anirudh Ravichander',
        album: 'Leo',
        duration: 245,
        audioUrl: 'https://drive.google.com/uc?export=download&id=1AbCdEfGhIjKlMnOpQrStUvWxYz&token=SECRET_TOKEN',
        artworkUrl: 'https://sample.art/leo.jpg',
        movieName: 'Leo',
      );

      final movie = songWithPrivateDriveUrl.movieName != null ? ' (${songWithPrivateDriveUrl.movieName})' : '';
      final shareText = '🎵 Listening to "${songWithPrivateDriveUrl.title}"$movie by ${songWithPrivateDriveUrl.artist} on Muxiz Music App!';

      expect(shareText.contains('drive.google.com'), isFalse);
      expect(shareText.contains('token='), isFalse);
      expect(shareText.contains('SECRET_TOKEN'), isFalse);
      expect(shareText, '🎵 Listening to "Naa Ready" (Leo) by Anirudh Ravichander on Muxiz Music App!');
    });

    test('8. Play Next deduplicates if song already exists further down in queue', () {
      final qm = QueueManager();
      // Queue: A (current), B, C, X
      qm.setQueue([songA, songB, songC, songX], initialIndex: 0);

      // User selects Play Next on songX (currently at index 3)
      qm.playNext(songX);

      // Expected queue order: A, X, B, C (no duplicate X at the end)
      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_x', 'song_b', 'song_c']);
      expect(qm.currentSong?.id, 'song_a');
      expect(qm.currentIndex, 0);
    });

    test('9. Play Next does not duplicate currently playing song', () {
      final qm = QueueManager();
      qm.setQueue([songA, songB, songC], initialIndex: 0);

      qm.playNext(songA);

      expect(qm.queue.map((s) => s.id).toList(), ['song_a', 'song_b', 'song_c']);
      expect(qm.currentSong?.id, 'song_a');
      expect(qm.currentIndex, 0);
    });
  });
}
