import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/audio_source_manager.dart';
import 'package:mobile/core/audio/offline_audio_source.dart';
import 'package:mobile/shared/models/song.dart';

void main() {
  group('AudioSourceManager Tests', () {
    const remoteSong = Song(
      id: 'remote_1',
      title: 'Online Song',
      artist: 'Online Artist',
      album: 'Online Album',
      artworkUrl: 'https://example.com/art.jpg',
      audioUrl: 'https://example.com/stream.mp3',
      duration: 240,
    );

    test('OfflineAudioSource returns false when local file is missing', () {
      expect(OfflineAudioSource.isAvailable(remoteSong), false);
    });

    test('createMediaItem creates valid MediaItem metadata', () {
      final mediaItem = AudioSourceManager.createMediaItem(remoteSong);
      expect(mediaItem.id, 'remote_1');
      expect(mediaItem.title, 'Online Song');
      expect(mediaItem.artist, 'Online Artist');
      expect(mediaItem.album, 'Online Album');
      expect(mediaItem.duration, const Duration(seconds: 240));
      expect(mediaItem.artUri, Uri.parse('https://example.com/art.jpg'));
    });
  });
}
