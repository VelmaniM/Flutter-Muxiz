import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/data/mock_catalog.dart';
import 'package:mobile/shared/models/song.dart';
import 'package:mobile/shared/models/album.dart';
import 'package:mobile/shared/models/playlist.dart';
import 'package:mobile/core/services/recommendation_service.dart';
import 'package:mobile/core/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();

    MockMusicCatalog.allSongs = [
      Song(
        id: 'song_1',
        title: 'Song From Movie Alpha',
        artist: 'Artist A',
        album: 'Album Alpha',
        movieName: 'Movie Alpha',
        duration: 210,
        audioUrl: 'https://example.com/1.mp3',
        artworkUrl: 'https://example.com/1.jpg',
      ),
      Song(
        id: 'song_2',
        title: 'Song From Movie Beta',
        artist: 'Artist B',
        album: 'Album Beta',
        movieName: 'Movie Beta',
        duration: 180,
        audioUrl: 'https://example.com/2.mp3',
        artworkUrl: 'https://example.com/2.jpg',
      ),
      Song(
        id: 'song_3',
        title: 'Song From Movie Gamma',
        artist: 'Artist C',
        album: 'Album Gamma',
        movieName: 'Movie Gamma',
        duration: 240,
        audioUrl: 'https://example.com/3.mp3',
        artworkUrl: 'https://example.com/3.jpg',
      ),
      Song(
        id: 'song_4',
        title: 'Trending Hit',
        artist: 'Artist D',
        album: 'Album Delta',
        movieName: 'Movie Delta',
        duration: 200,
        audioUrl: 'https://example.com/4.mp3',
        artworkUrl: 'https://example.com/4.jpg',
      ),
    ];

    MockMusicCatalog.topAlbums = [
      Album(
        id: 'album_alpha',
        title: 'Movie Alpha Original Soundtrack',
        artist: 'Artist A',
        artworkUrl: 'https://example.com/alpha.jpg',
        releaseYear: '2025',
        songs: [MockMusicCatalog.allSongs[0]],
      ),
    ];

    MockMusicCatalog.featuredPlaylists = [
      Playlist(
        id: 'top_hits_playlist',
        title: 'Top Hits 2026',
        description: 'Trending tracks',
        coverUrl: 'https://example.com/playlist.jpg',
        creator: 'Muxiz Editorial',
        songs: MockMusicCatalog.allSongs,
      ),
    ];
  });

  group('Dynamic 6-Grid Allocation Tests', () {
    test('Brand new user has clean starter state with 0 quickplay cards until they listen to a song', () {
      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed();

      // Brand new user has 0 cards so onboarding banner is shown
      expect(feed.quickPlayCards.isEmpty, isTrue);

      // Once user plays a song, all dynamic slots populate
      final activeFeed = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[0]);
      expect(activeFeed.quickPlayCards.length, greaterThanOrEqualTo(4));
      expect(activeFeed.quickPlayCards[0].song?.id, equals('song_1'));
    });

    test('When user plays Song 1 then Song 2 (different movie), Slot 1 becomes Song 2 and Slot 2 becomes Song 1', () async {
      final service = RecommendationService();

      // 1. User listens to Song 1 (Movie Alpha)
      await LocalStorageService.addRecentlyPlayed(MockMusicCatalog.allSongs[0]);

      var feed = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[0]);
      expect(feed.quickPlayCards[0].song?.id, equals('song_1'));

      // 2. User then listens to Song 2 (Movie Beta)
      await LocalStorageService.addRecentlyPlayed(MockMusicCatalog.allSongs[1]);

      feed = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[1]);

      // Slot 1 MUST be Song 2 (currently playing from Movie Beta)
      expect(feed.quickPlayCards[0].song?.id, equals('song_2'));

      // Slot 2 MUST be Song 1 (previous song from Movie Alpha)
      expect(feed.quickPlayCards[1].song?.id, equals('song_1'));
    });

    test('Slot 3, Slot 4, Slot 5, Slot 6 populate correctly with liked, album, trending, playlist', () async {
      final service = RecommendationService();

      // Mark Song 3 as liked
      await LocalStorageService.toggleFavoriteSong(MockMusicCatalog.allSongs[2]);
      await LocalStorageService.addRecentlyPlayed(MockMusicCatalog.allSongs[1]);
      await LocalStorageService.addRecentlyPlayed(MockMusicCatalog.allSongs[0]);

      final feed = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[0]);

      // Slot 1: Current song (Song 1)
      expect(feed.quickPlayCards[0].song?.id, equals('song_1'));

      // Slot 2: Previous song (Song 2)
      expect(feed.quickPlayCards[1].song?.id, equals('song_2'));

      // Slot 3: Liked song (Song 3)
      expect(feed.quickPlayCards[2].song?.id, equals('song_3'));

      // Slot 4: Top album
      expect(feed.quickPlayCards[3].album?.id, equals('album_alpha'));

      // Slot 5: Trending / other catalog song
      expect(feed.quickPlayCards[4].song?.id, equals('song_4'));

      // Slot 6: Playlist
      expect(feed.quickPlayCards[5].playlist?.id, equals('top_hits_playlist'));
    });

    test('Clear Cache wipes history and resets slots cleanly', () async {
      await LocalStorageService.addRecentlyPlayed(MockMusicCatalog.allSongs[0]);
      expect(LocalStorageService.getRecentlyPlayed().isNotEmpty, isTrue);

      await LocalStorageService.clearAllPlaybackAndCache();
      expect(LocalStorageService.getRecentlyPlayed().isEmpty, isTrue);
    });
  });
}
