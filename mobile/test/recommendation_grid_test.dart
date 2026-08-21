import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/data/mock_catalog.dart';
import 'package:mobile/shared/models/song.dart';
import 'package:mobile/shared/models/album.dart';
import 'package:mobile/shared/models/playlist.dart';
import 'package:mobile/shared/models/artist.dart';
import 'package:mobile/shared/models/listening_activity.dart';
import 'package:mobile/core/services/listening_tracker_service.dart';
import 'package:mobile/core/services/recommendation_service.dart';
import 'package:mobile/core/storage/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    ListeningTrackerService.instance.resetSession();

    MockMusicCatalog.allSongs = [
      const Song(
        id: 'song_1',
        title: 'Song From Movie Alpha',
        artist: 'Artist A',
        album: 'Album Alpha',
        movieName: 'Movie Alpha',
        duration: 210,
        audioUrl: 'https://example.com/1.mp3',
        artworkUrl: 'https://example.com/1.jpg',
      ),
      const Song(
        id: 'song_2',
        title: 'Song From Movie Beta',
        artist: 'Artist B',
        album: 'Album Beta',
        movieName: 'Movie Beta',
        duration: 180,
        audioUrl: 'https://example.com/2.mp3',
        artworkUrl: 'https://example.com/2.jpg',
      ),
      const Song(
        id: 'song_3',
        title: 'Song From Movie Gamma',
        artist: 'Artist C',
        album: 'Album Gamma',
        movieName: 'Movie Gamma',
        duration: 240,
        audioUrl: 'https://example.com/3.mp3',
        artworkUrl: 'https://example.com/3.jpg',
      ),
      const Song(
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

    MockMusicCatalog.popularArtists = [
      Artist(
        id: 'art_1',
        name: 'Artist A',
        imageUrl: 'https://example.com/art_a.jpg',
        monthlyListeners: '500K',
        topTracks: [MockMusicCatalog.allSongs[0]],
      ),
    ];
  });

  group('Home Feed & Recommendation System Tests', () {
    test('1. Clean Initial State: No fake default grid on 0 plays, dynamic 6-grid on play', () {
      final service = RecommendationService();
      final feedEmpty = service.generateLocalAlgorithmicFeed();

      // Zero fake default cards on brand new install with 0 history
      expect(feedEmpty.quickPlayCards.isEmpty, isTrue);

      // As soon as a song is played, dynamic 6-grid is generated and persisted
      final feedWithSong = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[0]);
      expect(feedWithSong.quickPlayCards.length, equals(6));
      expect(feedWithSong.quickPlayCards[0].title, isNotEmpty);
      expect(feedWithSong.quickPlayCards[0].imageUrl, isNotEmpty);
    });

    test('2. Meaningful Listen Tracking: Threshold >= 30s or >= 25% duration', () async {
      final tracker = ListeningTrackerService.instance;
      final song = MockMusicCatalog.allSongs[0];

      // Play 10s -> Not meaningful yet
      tracker.onSongStarted(song);
      tracker.onPositionUpdated(song, const Duration(seconds: 10), Duration(seconds: song.duration));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(LocalStorageService.getAllListeningActivities().isEmpty, isTrue);

      // Play 35s -> Meaningful listen recorded (>= 30s threshold)
      tracker.onPositionUpdated(song, const Duration(seconds: 35), Duration(seconds: song.duration));
      await Future.delayed(const Duration(milliseconds: 10));
      final activities = LocalStorageService.getAllListeningActivities();
      expect(activities.isNotEmpty, isTrue);
      expect(activities.any((a) => a.contentId == song.id), isTrue);
    });

    test('3. Recency Time-Decay Ranking: Recent plays rank higher than older plays', () async {
      final now = DateTime.now();

      // Recent listen (today)
      await LocalStorageService.saveListeningActivity(ListeningActivityRecord(
        contentId: 'song_2',
        contentType: QuickAccessContentType.song,
        title: 'Song 2',
        subtitle: 'Artist B',
        imageUrl: 'https://example.com/2.jpg',
        lastPlayedAt: now.subtract(const Duration(hours: 2)),
        playCount: 1,
      ));

      // Old listen (20 days ago)
      await LocalStorageService.saveListeningActivity(ListeningActivityRecord(
        contentId: 'song_3',
        contentType: QuickAccessContentType.song,
        title: 'Song 3',
        subtitle: 'Artist C',
        imageUrl: 'https://example.com/3.jpg',
        lastPlayedAt: now.subtract(const Duration(days: 20)),
        playCount: 1,
      ));

      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed();

      final song2Index = feed.quickPlayCards.indexWhere((c) => c.song?.id == 'song_2');
      final song3Index = feed.quickPlayCards.indexWhere((c) => c.song?.id == 'song_3');

      expect(song2Index, isNot(-1));
      expect(song2Index, lessThan(song3Index != -1 ? song3Index : 999));
    });

    test('4. Grid Stability: Rebuilding feed repeatedly maintains identical 6-grid order', () {
      final service = RecommendationService();
      final feed1 = service.generateLocalAlgorithmicFeed();
      final feed2 = service.generateLocalAlgorithmicFeed();

      expect(feed1.quickPlayCards.length, equals(feed2.quickPlayCards.length));
      for (int i = 0; i < feed1.quickPlayCards.length; i++) {
        expect(feed1.quickPlayCards[i].id, equals(feed2.quickPlayCards[i].id));
      }
    });

    test('5. Multi-User Storage Scoping: Switching user IDs isolates listening history', () async {
      // User 1 activity
      await LocalStorageService.saveUserId('user_1');
      await LocalStorageService.saveListeningActivity(ListeningActivityRecord(
        contentId: 'song_1',
        contentType: QuickAccessContentType.song,
        title: 'Song 1',
        subtitle: 'Artist A',
        imageUrl: 'https://example.com/1.jpg',
        lastPlayedAt: DateTime.now(),
      ));
      expect(LocalStorageService.getAllListeningActivities().length, equals(1));

      // Switch to User 2
      await LocalStorageService.saveUserId('user_2');
      expect(LocalStorageService.getAllListeningActivities().isEmpty, isTrue);
    });

    test('6. Continue Listening Home Section Removed: Feed MUST NOT contain continueListening shelf', () {
      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed();

      // Verify that NO continue listening section exists in Home feed
      final continueSection = feed.sections.where((s) => s.id == 'continue_listening').firstOrNull;
      expect(continueSection, isNull);
      final anyContinueSection = feed.sections.where((s) => s.title.toLowerCase().contains('continue')).firstOrNull;
      expect(anyContinueSection, isNull);
    });

    test('7. Fast Path: Current playing song immediately becomes valid top signal without waiting', () {
      final service = RecommendationService();
      final currentSong = MockMusicCatalog.allSongs[3]; // Trending Hit

      // Generate feed immediately with currentSong as fast local signal
      final feed = service.generateLocalAlgorithmicFeed(currentSong: currentSong);

      final hasSong4 = feed.quickPlayCards.any((c) => c.song?.id == 'song_4');
      expect(hasSong4, isTrue);
    });

    test('8. Dynamic Shelf Adaptation: Generates "Because you listened to Artist A"', () async {
      // User listens to Song 1 by Artist A
      await LocalStorageService.addRecentlyPlayed(MockMusicCatalog.allSongs[0]);

      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed();

      final becauseSection = feed.sections.where((s) => s.title.startsWith('Because you listened to')).firstOrNull;
      expect(becauseSection, isNotNull);
      expect(becauseSection!.title, contains('Artist A'));
      expect(becauseSection.songs?.isNotEmpty, isTrue);
    });

    test('9. Artwork & Content Diversity: MMR penalties prevent duplicate artwork from dominating', () {
      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[0]);

      final artworks = feed.quickPlayCards.map((c) => c.imageUrl).where((url) => url.isNotEmpty).toList();
      final uniqueArtworks = artworks.toSet();

      // Diversity check: Artwork must be diverse and unique across Quick Access slots
      expect(uniqueArtworks.length, equals(artworks.length));
    });

    test('10. Background Scoring Async Execution: Runs non-blocking and yields valid feed', () async {
      final service = RecommendationService();
      final feed = await service.computeBackgroundScoringAsync(currentSong: MockMusicCatalog.allSongs[0]);

      expect(feed.quickPlayCards.length, equals(6));
      expect(feed.sections.isNotEmpty, isTrue);
    });
  });
}
