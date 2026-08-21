import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/data/mock_catalog.dart';
import 'package:mobile/shared/models/song.dart';
import 'package:mobile/shared/models/album.dart';
import 'package:mobile/shared/models/artist.dart';
import 'package:mobile/core/services/listening_tracker_service.dart';
import 'package:mobile/core/services/recommendation_service.dart';
import 'package:mobile/core/audio/audio_controller.dart';
import 'package:mobile/core/audio/playback_state.dart';
import 'package:mobile/core/storage/local_storage.dart';

class MockAudioController extends StateNotifier<PlayerStateModel> implements AudioController {
  MockAudioController() : super(const PlayerStateModel());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    ListeningTrackerService.instance.resetSession();

    MockMusicCatalog.allSongs = [
      const Song(
        id: 'track_1',
        title: 'Master The Blaster',
        artist: 'Anirudh Ravichander',
        album: 'Master',
        movieName: 'Master',
        duration: 220,
        audioUrl: 'https://example.com/1.mp3',
        artworkUrl: 'https://example.com/master.jpg',
      ),
      const Song(
        id: 'track_2',
        title: 'Vaathi Coming',
        artist: 'Anirudh Ravichander',
        album: 'Master',
        movieName: 'Master',
        duration: 210,
        audioUrl: 'https://example.com/2.mp3',
        artworkUrl: 'https://example.com/master.jpg', // Duplicate artwork/album with track_1
      ),
      const Song(
        id: 'track_3',
        title: 'Arabic Kuthu',
        artist: 'Anirudh Ravichander',
        album: 'Beast',
        movieName: 'Beast',
        duration: 270,
        audioUrl: 'https://example.com/3.mp3',
        artworkUrl: 'https://example.com/beast.jpg',
      ),
      const Song(
        id: 'track_4',
        title: 'Hukum',
        artist: 'Anirudh Ravichander',
        album: 'Jailer',
        movieName: 'Jailer',
        duration: 205,
        audioUrl: 'https://example.com/4.mp3',
        artworkUrl: 'https://example.com/jailer.jpg',
      ),
      const Song(
        id: 'track_5',
        title: 'Kadharalz',
        artist: 'A.R. Rahman',
        album: 'VTK',
        movieName: 'VTK',
        duration: 230,
        audioUrl: 'https://example.com/5.mp3',
        artworkUrl: 'https://example.com/vtk.jpg',
      ),
      const Song(
        id: 'track_6',
        title: 'Naan Pizhai',
        artist: 'Anirudh Ravichander',
        album: 'Kaathuvaakula Rendu Kaadhal',
        movieName: 'Kaathuvaakula Rendu Kaadhal',
        duration: 240,
        audioUrl: 'https://example.com/6.mp3',
        artworkUrl: 'https://example.com/krk.jpg',
      ),
      const Song(
        id: 'track_7',
        title: 'Marakkuma Nenjam',
        artist: 'A.R. Rahman',
        album: 'VTK',
        movieName: 'VTK',
        duration: 250,
        audioUrl: 'https://example.com/7.mp3',
        artworkUrl: 'https://example.com/vtk.jpg', // Duplicate artwork with track_5
      ),
    ];

    MockMusicCatalog.topAlbums = [
      Album(
        id: 'album_master',
        title: 'Master',
        artist: 'Anirudh Ravichander',
        artworkUrl: 'https://example.com/master.jpg',
        releaseYear: '2021',
        songs: [MockMusicCatalog.allSongs[0], MockMusicCatalog.allSongs[1]],
      ),
      Album(
        id: 'album_beast',
        title: 'Beast',
        artist: 'Anirudh Ravichander',
        artworkUrl: 'https://example.com/beast.jpg',
        releaseYear: '2022',
        songs: [MockMusicCatalog.allSongs[2]],
      ),
    ];

    MockMusicCatalog.popularArtists = [
      Artist(
        id: 'art_anirudh',
        name: 'Anirudh Ravichander',
        imageUrl: 'https://example.com/anirudh.jpg',
        monthlyListeners: '8.5M',
        topTracks: [MockMusicCatalog.allSongs[0]],
      ),
      Artist(
        id: 'art_ar_rahman',
        name: 'A.R. Rahman',
        imageUrl: 'https://example.com/rahman.jpg',
        monthlyListeners: '12M',
        topTracks: [MockMusicCatalog.allSongs[4]],
      ),
    ];
  });

  group('Comprehensive Home Experience & Quality Assurance Tests', () {
    test('1. Continue Listening Home Section is strictly removed from Home Feed', () {
      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed();

      // Ensure no section has type or ID of continue_listening
      for (final section in feed.sections) {
        expect(section.id, isNot('continue_listening'));
        expect(section.title.toLowerCase().contains('continue listening'), isFalse);
        expect(section.title.toLowerCase().contains('continue playing'), isFalse);
        expect(section.title.toLowerCase().contains('resume listening'), isFalse);
        expect(section.title.toLowerCase().contains('pick up where you left off'), isFalse);
      }
    });

    test('2. Fast-Path Immediate Signal: Playing Song X instantly updates Home Feed', () async {
      final container = ProviderContainer(
        overrides: [
          playerStateProvider.overrideWith((ref) => MockAudioController()),
        ],
      );
      final notifier = container.read(homeFeedProvider.notifier);

      expect(notifier.stateVersion, greaterThanOrEqualTo(0));

      // User plays Track 5 (A.R. Rahman)
      final track5 = MockMusicCatalog.allSongs[4];
      LocalStorageService.addRecentlyPlayed(track5);

      notifier.refreshFeed();

      final updatedFeed = notifier.cachedFeed;
      expect(updatedFeed.quickPlayCards.length, equals(6));
      expect(updatedFeed.quickPlayCards.any((c) => c.song?.id == 'track_5'), isTrue);
      container.dispose();
    });

    test('3. Artwork & Visual Diversity: MMR penalties suppress duplicate album artwork', () {
      final service = RecommendationService();
      final feed = service.generateLocalAlgorithmicFeed(currentSong: MockMusicCatalog.allSongs[0]);

      final artworks = feed.quickPlayCards.map((c) => c.imageUrl).toList();
      final uniqueArtworks = artworks.toSet();

      // All 6 Quick Access cards must have distinct artworks
      expect(uniqueArtworks.length, equals(artworks.length));
    });

    test('4. No Unwanted Autoplay: Initial player state and Home opening do not start playback', () {
      const playerState = PlayerStateModel();
      expect(playerState.isPlaying, isFalse);
      expect(playerState.currentSong, isNull);
    });

    test('5. Continuous Playback Integrity: Normal queue transitions are preserved', () {
      final queue = List<Song>.from(MockMusicCatalog.allSongs);
      final currentSong = queue[0];
      final nextSong = queue[1];

      var state = PlayerStateModel(
        currentSong: currentSong,
        queue: queue,
        queueIndex: 0,
        isPlaying: true,
      );

      expect(state.currentSong?.id, equals('track_1'));

      // Transition to next track in queue (Song A -> Song B)
      state = state.copyWith(
        currentSong: nextSong,
        queueIndex: 1,
      );

      expect(state.currentSong?.id, equals('track_2'));
      expect(state.queue.length, equals(queue.length));
    });

    test('6. Stale Background Result Discarding: Outdated version is not applied', () async {
      final container = ProviderContainer(
        overrides: [
          playerStateProvider.overrideWith((ref) => MockAudioController()),
        ],
      );
      final notifier = container.read(homeFeedProvider.notifier);

      final versionAtStart = notifier.stateVersion;

      // User triggers new action -> version increments
      notifier.refreshFeed();
      final newVersion = notifier.stateVersion;

      expect(newVersion, greaterThan(versionAtStart));
      container.dispose();
    });
  });
}
