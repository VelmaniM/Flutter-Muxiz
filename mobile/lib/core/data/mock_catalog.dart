import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants.dart';
import '../../shared/models/song.dart';
import '../../shared/models/artist.dart';
import '../../shared/models/album.dart';
import '../../shared/models/playlist.dart';
import '../storage/local_storage.dart';
import '../services/metadata_extractor_service.dart';

class CatalogNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final catalogNotifier = CatalogNotifier();
final musicCatalogProvider = ChangeNotifierProvider<CatalogNotifier>((ref) => catalogNotifier);

class MockMusicCatalog {
  static List<Song> allSongs = [];
  static List<Artist> popularArtists = [];
  static List<Playlist> featuredPlaylists = [];
  static List<Album> topAlbums = [];
  static bool isInitialized = false;

  static Map<String, String> artistPortraits = {
    'sai abhyankkar': 'https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/cd/db/89/cddb89d2-79e7-7385-edc9-c3d50ff18505/mza_14310547933879091928.png/1000x1000bb.jpg',
    'sai abhyankar': 'https://is1-ssl.mzstatic.com/image/thumb/Features211/v4/cd/db/89/cddb89d2-79e7-7385-edc9-c3d50ff18505/mza_14310547933879091928.png/1000x1000bb.jpg',
    'anirudh ravichander': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f0/7c/ec/f07cec97-4d1a-da91-02a1-d1a0421ac840/199538343670.jpg/1000x1000bb.jpg',
    'anirudh': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f0/7c/ec/f07cec97-4d1a-da91-02a1-d1a0421ac840/199538343670.jpg/1000x1000bb.jpg',
    'a.r. rahman': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f3/fe/3f/f3fe3f04-f920-60f2-3115-16558b93b8fb/8909024118444.png/1000x1000bb.jpg',
    'ar rahman': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/f3/fe/3f/f3fe3f04-f920-60f2-3115-16558b93b8fb/8909024118444.png/1000x1000bb.jpg',
    'yuvan shankar raja': 'https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/5d/66/7a/5d667a79-b67b-19db-95db-69c985ae9f5e/884977467260.jpg/1000x1000bb.jpg',
    'yuvan': 'https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/5d/66/7a/5d667a79-b67b-19db-95db-69c985ae9f5e/884977467260.jpg/1000x1000bb.jpg',
    'harris jayaraj': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/49/a8/43/49a84369-7d6a-5905-af16-46eecbd2975d/196874700822.jpg/1000x1000bb.jpg',
    'sid sriram': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/93/e0/e6/93e0e603-2500-da00-520f-17c02cca2649/196589997289.jpg/1000x1000bb.jpg',
    'santhosh narayanan': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/e3/53/ab/e353ab4a-53c7-35ca-70f1-35ce24d2f89e/8903431060945_cover.jpg/1000x1000bb.jpg',
    'g.v. prakash kumar': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/fb/25/bf/fb25bfe6-f9f0-d015-0146-2def2faec80a/cover.jpg/1000x1000bb.jpg',
    'gv prakash': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/fb/25/bf/fb25bfe6-f9f0-d015-0146-2def2faec80a/cover.jpg/1000x1000bb.jpg',
    'ilaiyaraaja': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/ee/a1/8a/eea18a29-a74d-191b-cc8f-812793ad8153/885288330083.jpg/1000x1000bb.jpg',
    'ilayaraja': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/ee/a1/8a/eea18a29-a74d-191b-cc8f-812793ad8153/885288330083.jpg/1000x1000bb.jpg',
    's.p. balasubrahmanyam': 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/e5/5a/7d/e55a7de2-6854-cb33-d0c4-e6df703c2ea5/191773207656.jpg/1000x1000bb.jpg',
    'spb': 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/e5/5a/7d/e55a7de2-6854-cb33-d0c4-e6df703c2ea5/191773207656.jpg/1000x1000bb.jpg',
    'd. imman': 'https://is1-ssl.mzstatic.com/image/thumb/Music123/v4/b9/38/56/b9385651-5600-420f-f468-d61f367aaef4/886444281607.jpg/1000x1000bb.jpg',
    'hiphop tamizha': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/d6/ff/97/d6ff97ce-3f3a-f031-8847-f2f46a15f304/196871094689.jpg/1000x1000bb.jpg',
    'dhanush': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/8b/18/b7/8b18b7cf-856d-5fb7-7f6e-7af1ca538bcf/1200214401061.jpg/1000x1000bb.jpg',
    'shreya ghoshal': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/5f/f8/a5/5ff8a59a-5b12-b177-9fe0-295345e93765/26UMGIM78044.rgb.jpg/1000x1000bb.jpg',
    'pradeep kumar': 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/14/49/16/14491666-036a-ad4c-6927-d0d94426beb4/cover.jpg/1000x1000bb.jpg',
    'shankar mahadevan': 'https://is1-ssl.mzstatic.com/image/thumb/Music49/v4/93/cc/db/93ccdb69-815f-7e02-4450-21a358166970/190374418898.jpg/1000x1000bb.jpg',
    'k.j. yesudas': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/7f/7d/f5/7f7df5e0-445b-730e-79d2-4dbcfda09c88/886448881353.jpg/1000x1000bb.jpg',
    'kailash kher': 'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/b7/ed/e0/b7ede001-64fa-ce23-a9c6-c36f0a8c5684/888880944832.jpg/1000x1000bb.jpg',
    'chinmayi sripaada': 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/8d/8c/69/8d8c697e-f108-9e69-0cb1-475b45ab26a8/886970389020.jpg/1000x1000bb.jpg',
    'jonita gandhi': 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/88/22/e0/8822e0e9-f1a1-abba-f024-c9c7c4851477/8909024120546.png/1000x1000bb.jpg',
    'haricharan': 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/18/7c/39/187c394c-95af-735f-82cf-16eca48a7290/886443235984.jpg/1000x1000bb.jpg',
    'karthik': 'https://is1-ssl.mzstatic.com/image/thumb/Music5/v4/74/48/f1/7448f195-981a-0fc8-e314-8b90850ee63c/cover.jpg/1000x1000bb.jpg',
    'shweta mohan': 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/9e/fc/87/9efc8706-fe89-127d-5aa2-08b065dcb2ca/886445635423.jpg/1000x1000bb.jpg',
    'sathyaprakash': 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/c9/36/8f/c9368f60-7281-fdcf-f8fb-9cf7090189d7/886446711492.jpg/1000x1000bb.jpg',
    'anthony daasan': 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/e8/0d/bb/e80dbb61-121e-e679-8fb8-4b2c092d21fa/196589119032.jpg/1000x1000bb.jpg',
    'd. sathyaprakash': 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/c9/36/8f/c9368f60-7281-fdcf-f8fb-9cf7090189d7/886446711492.jpg/1000x1000bb.jpg',
    'stephen zechariah': 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/ad/07/ee/ad07ee29-1662-7907-8857-414aeec1fb3a/196626578709.jpg/1000x1000bb.jpg',
    'sam c.s.': 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/05/ae/3a/05ae3a61-a083-d958-8547-8cfba54a5c53/8902894354388.jpg/1000x1000bb.jpg',
    'sean roldan': 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/71/8d/8b/718d8bb5-6b5d-e08f-e14b-21a4bc5c5c0a/8903431671912_cover.jpg/1000x1000bb.jpg',
  };

  static String _songDedupKey(Song s) {
    final title = s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final movie = (s.movieName ?? s.album).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${title}___$movie';
  }

  /// Normalizes artist names to prevent duplicate variations of the same artist
  static String normalizeArtistName(String raw) {
    if (raw.isEmpty) return 'Various Artists';
    var clean = raw.split(',')[0].split('&')[0].split(';')[0].split('/')[0].trim();
    clean = clean.replaceAll(RegExp(r'\b(feat\.|ft\.|presents|duet)\b.*$', caseSensitive: false), '').trim();
    final lower = clean.toLowerCase();

    if (lower.contains('sai abhyankkar') || lower.contains('sai abhyankar') || lower.contains('abhyankkar')) return 'Sai Abhyankkar';
    if (lower.contains('stephen zechariah') || lower.contains('stephen')) return 'Stephen Zechariah';
    if (lower.contains('sam c.s.') || lower.contains('sam cs')) return 'Sam C.S.';
    if (lower.contains('sean roldan')) return 'Sean Roldan';
    if (lower.contains('rahman') || lower == 'ar' || lower == 'a r rahman' || lower == 'a. r. rahman') return 'A.R. Rahman';
    if (lower.contains('anirudh')) return 'Anirudh Ravichander';
    if (lower.contains('yuvan')) return 'Yuvan Shankar Raja';
    if (lower.contains('harris')) return 'Harris Jayaraj';
    if (lower.contains('santhosh')) return 'Santhosh Narayanan';
    if (lower.contains('gv prakash') || lower.contains('g.v. prakash') || lower.contains('g. v. prakash')) return 'G.V. Prakash Kumar';
    if (lower.contains('ilaiyaraaja') || lower.contains('ilayaraja')) return 'Ilaiyaraaja';
    if (lower.contains('spb') || lower.contains('balasubrahmanyam') || lower.contains('s. p. balasubrahmanyam')) return 'S.P. Balasubrahmanyam';
    if (lower.contains('imman') || lower.contains('d imman') || lower.contains('d. imman')) return 'D. Imman';
    if (lower.contains('hiphop')) return 'Hiphop Tamizha';
    if (lower.contains('sid sriram')) return 'Sid Sriram';
    if (lower.contains('pradeep')) return 'Pradeep Kumar';
    if (lower.contains('shreya')) return 'Shreya Ghoshal';
    if (lower.contains('yesudas')) return 'K.J. Yesudas';
    if (lower.contains('dhanush')) return 'Dhanush';
    if (lower.contains('shankar mahadevan')) return 'Shankar Mahadevan';
    if (lower.contains('kailash kher') || lower.contains('kailash')) return 'Kailash Kher';
    if (lower.contains('chinmayi')) return 'Chinmayi Sripaada';
    if (lower.contains('jonita')) return 'Jonita Gandhi';
    if (lower.contains('haricharan')) return 'Haricharan';
    if (lower.contains('karthik')) return 'Karthik';
    if (lower.contains('vijay yesudas')) return 'Vijay Yesudas';
    if (lower.contains('swetha mohan') || lower.contains('shweta mohan') || lower.contains('shweta')) return 'Shweta Mohan';
    if (lower.contains('sathyaprakash') || lower.contains('d.sathyaprakash') || lower.contains('d. sathyaprakash')) return 'Sathyaprakash';
    return clean.isNotEmpty ? clean : 'Various Artists';
  }

  /// Returns only the songs strictly composed or sung by [artistName]
  static List<Song> getSongsForArtist(String artistName) {
    final targetNormalized = normalizeArtistName(artistName).toLowerCase();
    final targetRawLower = artistName.toLowerCase().trim();

    return allSongs.where((s) {
      final songArtistNormalized = normalizeArtistName(s.artist).toLowerCase();
      if (songArtistNormalized == targetNormalized) return true;

      final songArtistRaw = s.artist.toLowerCase();
      if (songArtistRaw.contains(targetRawLower) || songArtistRaw.contains(targetNormalized)) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Returns whether a song is strictly by a specific artist
  static bool isSongByArtist(Song s, String artistName) {
    final targetNormalized = normalizeArtistName(artistName).toLowerCase();
    final songArtistNormalized = normalizeArtistName(s.artist).toLowerCase();
    if (songArtistNormalized == targetNormalized) return true;

    final targetRawLower = artistName.toLowerCase().trim();
    final songArtistRaw = s.artist.toLowerCase();
    return songArtistRaw.contains(targetRawLower) || songArtistRaw.contains(targetNormalized);
  }

  /// Normalizes movie and album names so all songs of the same movie group into one Album
  static String normalizeMovieOrAlbumName(Song s) {
    var raw = (s.movieName != null && s.movieName!.trim().isNotEmpty && s.movieName != 'Single')
        ? s.movieName!.trim()
        : (s.album.trim().isNotEmpty && s.album != 'Single' ? s.album.trim() : '');

    if (raw.isEmpty) {
      return 'Tamil Originals';
    }

    // Clean common noisy suffixes
    var clean = raw.replaceAll(
      RegExp(r'\s*(\((original motion picture soundtrack|ost|soundtrack|tamil|album|songs|original score|\d{4})\)|\[.*?\])', caseSensitive: false),
      '',
    ).trim();

    return clean.isNotEmpty ? clean : raw;
  }

  /// Permanently removes a song from in-memory catalog and rebuilds artists & playlists
  static void removeSong(String songId) {
    allSongs.removeWhere((s) => s.id == songId);
    _buildArtistsAndAlbums();
    _buildPlaylists();
    LocalStorageService.saveCatalogSongsLocally(allSongs);
    catalogNotifier.notify();
  }

  static void syncSong(Song song) {
    allSongs.removeWhere((s) => s.id == song.id);
    allSongs.insert(0, song);
    _buildArtistsAndAlbums();
    _buildPlaylists();
    LocalStorageService.saveCatalogSongsLocally(allSongs);
    catalogNotifier.notify();
  }

  static Future<void> initializeCatalog({bool forceRefresh = false}) async {
    final deletedSongIds = LocalStorageService.getDeletedSongIds();

    if (forceRefresh) {
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
    }

    // 1. Instantly load locally cached songs from previous sessions so UI renders with 0ms delay
    final cachedSongs = LocalStorageService.getCatalogSongsLocally();
    if (allSongs.isEmpty && cachedSongs.isNotEmpty && !forceRefresh) {
      allSongs = cachedSongs.where((s) => !deletedSongIds.contains(s.id)).toList();
      _buildArtistsAndAlbums();
      _buildPlaylists();
      catalogNotifier.notify();
    }

    // 2. Load bundled asset catalog immediately if still empty (ensures instant 0ms offline/fresh start)
    if (allSongs.isEmpty) {
      try {
        final jsonString = await rootBundle.loadString('assets/data/music_catalog.json');
        final dynamic decoded = json.decode(jsonString);
        final list = (decoded is Map ? (decoded['data'] ?? decoded['songs']) : decoded) as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final List<Song> assetSongs = [];
          for (final item in list) {
            final id = (item['id'] ?? '').toString();
            if (id.isEmpty || deletedSongIds.contains(id)) continue;
            assetSongs.add(Song.fromJson(Map<String, dynamic>.from(item as Map)));
          }
          if (assetSongs.isNotEmpty) {
            allSongs = assetSongs;
            _buildArtistsAndAlbums();
            _buildPlaylists();
            isInitialized = true;
            catalogNotifier.notify();
          }
        }
      } catch (e) {
        debugPrint('Error loading asset catalog: $e');
      }
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
      ));

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Fetch live songs from PostgreSQL Database & Google Drive backend endpoints (fetch ALL DB songs)
      final candidateEndpoints = [
        '${AppConstants.defaultApiBaseUrl}/songs?limit=10000&t=$timestamp&nocache=1',
        '${AppConstants.defaultApiBaseUrl}/songs?limit=10000',
        ...AppConstants.fallbackApiBaseUrls.map((u) => '$u/songs?limit=10000&t=$timestamp'),
        'https://muxiz.vercel.app/api/drive/songs?limit=10000&t=$timestamp',
      ];

      for (final endpoint in candidateEndpoints) {
        try {
          final res = await dio.get(endpoint);
          if (res.statusCode == 200 && res.data != null) {
            final data = res.data;
            final list = (data is Map ? (data['data'] ?? data['songs']) : data) as List<dynamic>?;
            if (list != null && list.isNotEmpty) {
              final List<Song> backendSongs = [];
              for (final item in list) {
                final id = (item['id'] ?? '').toString();
                if (id.isEmpty || deletedSongIds.contains(id)) continue;

                final song = Song(
                  id: id,
                  title: (item['title'] ?? 'Untitled Track').toString(),
                  artist: (item['artistName'] ?? item['artist']?['name'] ?? item['artist'] ?? 'Unknown Artist').toString(),
                  album: (item['albumName'] ?? item['album']?['title'] ?? item['album'] ?? 'Single').toString(),
                  movieName: item['movieName']?.toString(),
                  artworkUrl: (item['artworkUrl'] ?? item['artwork'] ?? '').toString(),
                  audioUrl: (item['audioUrl'] ?? '').toString(),
                  duration: (item['duration'] as num?)?.toInt() ?? 180,
                  genre: (item['genre'] ?? 'Music').toString(),
                  language: (item['language'] ?? 'Tamil').toString(),
                  lyrics: (item['lyrics'] is List) ? List<String>.from(item['lyrics']) : [],
                );

                backendSongs.add(song);
              }

              // EXACT DB SYNC: Frontend reflects the exact songs currently active in the database
              if (backendSongs.isNotEmpty) {
                allSongs = backendSongs;
                _buildArtistsAndAlbums();
                _buildPlaylists();
                LocalStorageService.saveCatalogSongsLocally(allSongs);
                isInitialized = true;
                catalogNotifier.notify();
                debugPrint('🎵 Muxiz Music Catalog Synced with DB: ${allSongs.length} Songs, ${popularArtists.length} Artists!');
                break;
              }
            }
          }
        } catch (_) {}
      }

      // Build All Unique Artists and All Unique Movie Albums
      _buildArtistsAndAlbums();

      // Build Featured Playlists
      _buildPlaylists();

      // Persist latest state
      LocalStorageService.saveCatalogSongsLocally(allSongs);

      isInitialized = true;
      catalogNotifier.notify();
      debugPrint('🎵 Muxiz Music Catalog: ${allSongs.length} Songs, ${popularArtists.length} Artists, ${topAlbums.length} Movie Albums!');
    } catch (e) {
      debugPrint('Error loading music catalog: $e');
    }
  }

  static void _buildArtistsAndAlbums() {
    final Map<String, List<Song>> artistMap = {};
    final Map<String, List<Song>> albumMap = {};
    final Map<String, Set<String>> artistSongKeys = {};
    final Map<String, Set<String>> albumSongKeys = {};

    for (final s in allSongs) {
      // 1. Group by Normalized Unique Artist
      final artistName = normalizeArtistName(s.artist);
      if (artistName.isNotEmpty && artistName != 'Various Artists') {
        artistSongKeys.putIfAbsent(artistName, () => {});
        if (!artistSongKeys[artistName]!.contains(s.id)) {
          artistSongKeys[artistName]!.add(s.id);
          artistMap.putIfAbsent(artistName, () => []).add(s);
        }
      }

      // 2. Group by Normalized Unique Movie / Album
      final movieOrAlbum = normalizeMovieOrAlbumName(s);
      if (movieOrAlbum.isNotEmpty && movieOrAlbum != 'Single') {
        albumSongKeys.putIfAbsent(movieOrAlbum, () => {});
        if (!albumSongKeys[movieOrAlbum]!.contains(s.id)) {
          albumSongKeys[movieOrAlbum]!.add(s.id);
          albumMap.putIfAbsent(movieOrAlbum, () => []).add(s);
        }
      }
    }

    // Sort all unique artists by number of songs
    final sortedArtistEntries = artistMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    popularArtists = sortedArtistEntries.map((e) {
      final firstSong = e.value.first;
      final artistKey = e.key.toLowerCase().trim();
      final cachedPortrait = artistPortraits[artistKey];
      final realPortrait = cachedPortrait ?? firstSong.artworkUrl;

      // Asynchronously query Apple Music for official artist master portrait if not cached
      if (cachedPortrait == null) {
        MetadataExtractorService.fetchArtistPortrait(e.key).then((portraitUrl) {
          if (portraitUrl != null && portraitUrl.isNotEmpty) {
            artistPortraits[artistKey] = portraitUrl;
            final idx = popularArtists.indexWhere((a) => a.id == e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'));
            if (idx != -1) {
              final old = popularArtists[idx];
              popularArtists[idx] = Artist(
                id: old.id,
                name: old.name,
                imageUrl: portraitUrl,
                monthlyListeners: old.monthlyListeners,
                bio: old.bio,
                topTracks: old.topTracks,
              );
            }
          }
        });
      }

      return Artist(
        id: e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        name: e.key,
        imageUrl: realPortrait,
        monthlyListeners: '${(e.value.length * 1.2).toStringAsFixed(1)}M',
        bio: 'Popular Tamil composer & artist with ${e.value.length}+ tracks.',
        topTracks: e.value,
      );
    }).toList();

    // Sort all unique movie albums by number of songs
    final sortedAlbumEntries = albumMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    topAlbums = sortedAlbumEntries.map((e) {
      final firstSong = e.value.first;
      // Determine primary composer/artist for the movie album
      final Map<String, int> artistCounts = {};
      for (final s in e.value) {
        final a = normalizeArtistName(s.artist);
        if (a.isNotEmpty && a != 'Various Artists') {
          artistCounts[a] = (artistCounts[a] ?? 0) + 1;
        }
      }
      final primaryAlbumArtist = artistCounts.isNotEmpty
          ? (artistCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key
          : normalizeArtistName(firstSong.artist);

      return Album(
        id: e.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
        title: e.key,
        artist: primaryAlbumArtist,
        artworkUrl: firstSong.artworkUrl,
        releaseYear: '2024',
        songs: e.value,
      );
    }).toList();
  }

  static void _buildPlaylists() {
    if (allSongs.isEmpty) return;

    final viralHits = allSongs.where((s) {
      final m = (s.movieName ?? s.album).toLowerCase();
      final t = s.title.toLowerCase();
      return m.contains('goat') ||
          m.contains('amaran') ||
          m.contains('vettaiyan') ||
          m.contains('leo') ||
          m.contains('jailer') ||
          t.contains('spark') ||
          t.contains('matta') ||
          t.contains('minnale') ||
          t.contains('katchi');
    }).take(20).toList();

    final massBeats = allSongs.where((s) {
      final a = normalizeArtistName(s.artist);
      final g = s.genre.toLowerCase();
      final t = s.title.toLowerCase();
      return (a == 'Anirudh Ravichander' || a == 'Santhosh Narayanan' || a == 'Hiphop Tamizha') &&
          (g.contains('dance') || g.contains('soundtrack') || t.contains('mass') || t.contains('theme') || t.contains('anthem') || t.contains('kuthu') || t.contains('hukum') || t.contains('badass'));
    }).take(20).toList();

    final melodies = allSongs.where((s) {
      final a = normalizeArtistName(s.artist);
      final t = s.title.toLowerCase();
      return (a == 'A.R. Rahman' || a == 'Harris Jayaraj' || a == 'Sid Sriram' || a == 'Pradeep Kumar') &&
          (t.contains('love') || t.contains('kadhal') || t.contains('melody') || t.contains('kanave') || t.contains('uyire') || t.contains('nenj'));
    }).take(20).toList();

    final yuvanSongs = allSongs.where((s) => isSongByArtist(s, 'Yuvan Shankar Raja')).take(25).toList();

    final deletedPlaylists = LocalStorageService.getDeletedPlaylistIds();

    final candidatePlaylists = [
      if (viralHits.isNotEmpty)
        Playlist(
          id: 'todays_top_hits',
          title: 'Today\'s Top Hits',
          description: 'Trending Tamil bangers from Leo, The GOAT, Amaran, and Vettaiyan.',
          coverUrl: viralHits.first.artworkUrl,
          creator: 'Muxiz Editorial',
          songs: viralHits,
        ),
      if (massBeats.isNotEmpty)
        Playlist(
          id: 'tamil_mass_beats',
          title: 'Tamil Mass Beats',
          description: 'High energy gym and drive anthems by Anirudh & Santhosh Narayanan.',
          coverUrl: massBeats.first.artworkUrl,
          creator: 'Made For You',
          songs: massBeats,
        ),
      if (melodies.isNotEmpty)
        Playlist(
          id: 'melody_express',
          title: 'Melody & Romance',
          description: 'Soulful late night melodies by A.R. Rahman, Harris Jayaraj & Sid Sriram.',
          coverUrl: melodies.first.artworkUrl,
          creator: 'Muxiz Chill',
          songs: melodies,
        ),
      if (yuvanSongs.isNotEmpty)
        Playlist(
          id: 'yuvan_classics',
          title: 'U1 Drugs 💊',
          description: 'Iconic evergreen BGM and melodies strictly by Yuvan Shankar Raja.',
          coverUrl: yuvanSongs.first.artworkUrl,
          creator: 'Muxiz',
          songs: yuvanSongs,
        ),
    ];

    featuredPlaylists = candidatePlaylists.where((p) => !deletedPlaylists.contains(p.id)).toList();
  }

  static void addSong(Song song) {
    final key = _songDedupKey(song);
    if (!allSongs.any((s) => _songDedupKey(s) == key)) {
      allSongs.insert(0, song);
      _buildArtistsAndAlbums();
      _buildPlaylists();
    }
  }
}
